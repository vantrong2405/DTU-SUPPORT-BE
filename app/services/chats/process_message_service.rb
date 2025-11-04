# frozen_string_literal: true

class Chats::ProcessMessageService < BaseService
  MAX_HISTORY_MESSAGES = 8
  TEMPERATURE = 0.0
  TOP_P = 1.0
  TOP_K = 1
  DEFAULT_TONE = "Thân thiện, chuyên nghiệp, súc tích"
  UI_COMPONENTS = {
    "calculateTargetGpa"     => "GpaResultCard",
    "calculateSimulationGpa" => "GpaResultCard",
    "calculatePeGpa"         => "PeResultCard",
  }.freeze

  GRADE_POINTS = {
    "A+" => 4.0, "A" => 4.0, "A-" => 3.65,
    "B+" => 3.33, "B" => 3.0, "B-" => 2.65,
    "C+" => 2.33, "C" => 2.0, "C-" => 1.65,
    "D" => 1.0, "F" => 0.0,
  }.freeze

  GRADE_LABELS = {
    "A+" => "A+", "A" => "A", "A-" => "A−",
    "B+" => "B+", "B" => "B", "B-" => "B−",
    "C+" => "C+", "C" => "C", "C-" => "C−",
    "D" => "D", "F" => "F",
  }.freeze
  def initialize(messages:, tone: nil)
    super()
    @messages = messages
    @tone = tone
  end

  def call
    generation_context = build_generation_context
    resp = generate(generation_context, function_response: nil)
    return handle_function_call(generation_context:, resp:) if resp[:function_call]
    return { success: false, error: "Empty model output", code: "empty_model_output" } if resp[:text].blank?
    success_response(content: resp[:text])
  rescue Gemini::ApiError => e
    Rails.logger.error("Gemini API Error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
    { success: false, error: e.message }
  rescue StandardError => e
    Rails.logger.error("Unexpected Error in ProcessMessageService: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
    { success: false, error: e.message }
  end

  private

  def generate(generation_context, function_response: nil)
    generation_context[:gemini].generate_content(
      prompt:             generation_context[:user],
      system_instruction: generation_context[:sys],
      history:            generation_context[:history],
      temperature:        TEMPERATURE,
      top_p:              TOP_P,
      top_k:              TOP_K,
      tools:              generation_context[:tools],
      function_response:,
    )
  end

  def handle_function_call(generation_context:, resp:)
    tool_result = execute_tool(resp[:function_call])
    fr = { name: resp[:function_call][:name], function_call: resp[:function_call], response: tool_result }
    final_resp = generate(generation_context, function_response: fr)
    if final_resp[:text].blank?
      return { success: false, error: "Empty model output after tool execution",
code: "empty_model_output", }
    end

    success_response(content: final_resp[:text], tool_name: resp[:function_call][:name], tool_result:)
  end

  def build_generation_context
    {
      gemini:  Gemini.new,
      sys:     build_system_instruction,
      history: convert_messages_to_gemini_format(@messages),
      user:    @messages.last[:content],
      tools:   Chats::ToolsDefinitionService.new.call,
    }
  end

  def success_response(content:, tool_name: nil, tool_result: nil)
    return { success: true, content:, tool_result: nil, metadata: build_metadata } unless tool_name

    { success:     true,
      content:,
      tool_result: { toolName: tool_name, data: tool_result, uiComponent: get_ui_component(tool_name) },
      metadata:    build_metadata(intent: "calculation"), }
  end

  def build_system_instruction
    @build_system_instruction ||= begin
      raw = File.read(Rails.root.join("config/prompts/edubot_system.txt"))
      tone_text = (@tone.presence || DEFAULT_TONE).to_s
      raw.gsub("{{TONE}}", tone_text)
    end
  end

  def convert_messages_to_gemini_format(messages)
    return [] if messages.blank?

    recent = messages.last(MAX_HISTORY_MESSAGES)
    history_only = recent[0..-2] || []

    history_only.map do |msg|
      { role: msg[:role] == "user" ? "user" : "model", parts: [{ text: msg[:content] }] }
    end
  end

  def execute_tool(function_call)
    tool_name = function_call[:name]
    tool_args = function_call[:args] || {}

    case tool_name
    when "calculateTargetGpa" then execute_calculate_target_gpa(tool_args)
    when "calculateSimulationGpa" then execute_calculate_simulation_gpa(tool_args)
    when "calculatePeGpa" then execute_calculate_pe_gpa(tool_args)
    else { error: "Tool #{tool_name} not implemented yet" }
    end
  end

  # rubocop:disable Metrics/MethodLength
  def execute_calculate_target_gpa(args)
    completed_credits = args["completedCredits"].to_i
    current_gpa = args["currentGpa"].to_f
    remaining_credits = args["remainingCredits"].to_i
    target_gpa = args["targetGpa"]&.to_f

    total_credits = completed_credits + remaining_credits
    return { error: "Invalid parameters" } if total_credits.zero?

    max_gpa = ((completed_credits * current_gpa) + (remaining_credits * 4.0)) / total_credits

    {
      maxGpaWithAllA:           round_to_3_decimals(max_gpa),
      canReachTarget:           target_gpa ? max_gpa >= target_gpa : nil,
      graduationClassification: get_graduation_classification(max_gpa),
    }
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  def execute_calculate_simulation_gpa(args)
    completed_credits = args["completedCredits"].to_i
    current_gpa = args["currentGpa"].to_f
    args["remainingCredits"].to_i
    credit_distributions = args["creditDistributions"]

    total_remaining_credits = credit_distributions.sum { |dist| dist["credits"].to_i }

    total_remaining_points = credit_distributions.sum do |dist|
      dist["credits"].to_i * get_grade_point(dist["gradeValue"])
    end

    remaining_gpa = total_remaining_points.to_f / total_remaining_credits
    total_credits = completed_credits + total_remaining_credits
    final_gpa = ((completed_credits * current_gpa) + total_remaining_points) / total_credits

    distribution_summary = credit_distributions.map do |dist|
      "#{dist['credits']} tín #{get_grade_label(dist['gradeValue'])}"
    end.join(", ")

    {
      finalGpa:                 round_to_3_decimals(final_gpa),
      remainingGpa:             round_to_3_decimals(remaining_gpa),
      totalCredits:             total_credits,
      graduationClassification: get_graduation_classification(final_gpa),
      distributionSummary:      distribution_summary,
      isWeakResult:             final_gpa < 2.0,
    }
  end
  # rubocop:enable Metrics/MethodLength

  def execute_calculate_pe_gpa(args)
    pe_1 = args["pe1"].to_f
    pe_2 = args["pe2"].to_f
    pe_3 = args["pe3"].to_f

    average = round_to_3_decimals((pe_1 + pe_2 + pe_3) / 3.0)

    {
      average:,
      isPass:  average >= 2.0,
      inputs:  { "pe1" => pe_1, "pe2" => pe_2, "pe3" => pe_3 },
    }
  end

  def get_graduation_classification(gpa)
    return { rank: "excellent", minGpa: 3.60, maxGpa: 4.00 } if (3.60..4.00).cover?(gpa)
    return { rank: "good", minGpa: 3.20, maxGpa: 3.59 } if (3.20...3.60).cover?(gpa)
    return { rank: "fair", minGpa: 2.50, maxGpa: 3.19 } if (2.50...3.20).cover?(gpa)
    return { rank: "average", minGpa: 2.00, maxGpa: 2.49 } if (2.00...2.50).cover?(gpa)
    { rank: "below_average", minGpa: 0.0, maxGpa: 1.99 }
  end

  def get_grade_point(grade_value)
    GRADE_POINTS[grade_value.to_s] || 0.0
  end

  def get_grade_label(grade_value)
    GRADE_LABELS[grade_value.to_s] || grade_value.to_s
  end

  def round_to_3_decimals(value)
    (value * 1000).round / 1000.0
  end

  def get_ui_component(tool_name)
    UI_COMPONENTS[tool_name]
  end

  def build_metadata(intent: nil)
    { messageId: "msg-#{Time.current.to_i}-#{rand(1000..9999)}", timestamp: Time.current.iso8601,
intent: intent || "question", }
  end
end

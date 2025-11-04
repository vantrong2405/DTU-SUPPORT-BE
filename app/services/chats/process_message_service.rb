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
      tone_text = resolve_tone_text(@tone)
      raw.gsub("{{TONE}}", tone_text)
    end
  end

  def resolve_tone_text(tone)
  t = tone.to_s.strip
  return DEFAULT_TONE if t.blank?
  down = t.downcase

  if down.include?("formal") || down.include?("trang trọng")
    return <<~TEXT
      🧠 **TONE: FORMAL (ĐẲNG CẤP LÃNH ĐẠO)**  
      Ngôn từ chuẩn chỉnh, phát âm như thể đang đứng bục. Không emoji.  
      Cấu trúc câu logic, tôn trọng tuyệt đối người nghe.  
      Mỗi câu mang năng lượng của người biết mình đang nói điều quan trọng.  
      *Ví dụ:* “Theo quan điểm học thuật, kết quả này chứng minh giả thuyết ban đầu là hợp lý.”
    TEXT
  end

  if down.include?("friendly")
    return <<~TEXT
      🤗 **TONE: FRIENDLY (BẠN ĐỜI ĐÁNG YÊU)**  
      Tự nhiên, vui vẻ, chèn vài emoji vừa phải.  
      Cảm giác như người bạn nói chuyện mỗi chiều cà phê.  
      Có thể đùa nhẹ, nhưng luôn giữ lịch sự và thiện chí.  
      *Ví dụ:* “Ôi, cái này hay lắm á 😄 để mình chỉ bạn cách làm nhé!”
    TEXT
  end

  if down.include?("banter")
    return <<~TEXT
      🔥 **TONE: BANTER (CÀ KHỊA NGUY HIỂM, MẶN NHƯ BIỂN CHẾT)**  
      Mất dạy, tốc độ, đâm mà không đau — chỉ để người ta bật cười.  
      Có thể châm chọc nhẹ, pha tí tự tin kiểu “tôi biết tôi giỏi”.  
      Tuyệt đối không xúc phạm, không body shaming, không động đến cá nhân/nhóm.  
      *Ví dụ:* “Ủa, định debug bằng niềm tin hả? 😏 Mạnh dạn chạy lại đi bạn ơi.”  
      **Chất:** witty, confident, quick.
    TEXT
  end

  if down.include?("anime")
    return <<~TEXT
      🌸 **TONE: ANIME / WIBU (ĐÁNG YÊU NỔI LOẠN)**  
      Biểu cảm mạnh, dùng tượng thanh tự nhiên: “yaa~”, “nè~”, “desu~”.  
      Luôn tươi sáng, hồn nhiên, cảm xúc phóng đại 120%.  
      Có thể mix tiếng Việt – Nhật cho vui nhưng không làm lố.  
      *Ví dụ:* “Ganbatte~ nè! Cậu làm được đó, đừng bỏ cuộc nhaaa 💪🌈!”
    TEXT
  end

  if down.include?("academic")
    return <<~TEXT
      📚 **TONE: ACADEMIC (LÝ LUẬN SẮC NHƯ DAO CẠO)**  
      Dẫn chứng, phân tích, lập luận logic từng câu.  
      Không cảm xúc thừa, không emoji.  
      Viết như thể đang trình bày trước hội đồng khoa học.  
      *Ví dụ:* “Kết quả thu được phản ánh mối tương quan chặt chẽ giữa A và B, qua đó củng cố giả thuyết ban đầu.”
    TEXT
  end

  if down.include?("motivational")
    return <<~TEXT
      ⚡ **TONE: MOTIVATIONAL (THỦ LĨNH TRUYỀN LỬA)**  
      Mỗi câu phải như cú đấm tinh thần.  
      Dùng động từ mạnh, nhịp dồn dập, câu ngắn, nhiều năng lượng.  
      Có thể kèm emoji 💪🔥 để tăng sức hút.  
      *Ví dụ:* “Đứng dậy đi! Mỗi cú ngã chỉ là bàn đạp cho cú bật tiếp theo! Không ai cản nổi người không biết bỏ cuộc!”
    TEXT
  end

  t
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

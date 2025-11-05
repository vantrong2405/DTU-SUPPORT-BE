# frozen_string_literal: true

class Chats::ProcessMessageService < BaseService
  MAX_HISTORY_MESSAGES = 8
  TEMPERATURE = 0.0
  TOP_P = 1.0
  TOP_K = 1
  DEFAULT_TONE = "Thân thiện, chuyên nghiệp, súc tích"
  UI_COMPONENTS = {
    "calculateTargetGpa"          => "GpaResultCard",
    "calculateSimulationGpa"      => "GpaResultCard",
    "calculatePeGpa"              => "PeResultCard",
    "calculateRequiredFinalScore" => "FinalScoreResultCard",
    "calculateFinalScore"         => "FinalScoreResultCard",
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

  SCORE_TO_LETTER = {
    (9.5..10.0) => "A+", (8.5..9.4) => "A", (8.0..8.4) => "A-",
    (7.5..7.9) => "B+", (7.0..7.4) => "B", (6.5..6.9) => "B-",
    (6.0..6.4) => "C+", (5.5..5.9) => "C", (4.5..5.4) => "C-",
    (4.0..4.4) => "D", (0.0..3.9) => "F",
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
        🧠 **TONE: FORMAL (ĐẲNG CẤP LÃNH ĐẠO)**#{'  '}
        Ngôn từ chuẩn chỉnh, phát âm như thể đang đứng bục. Không emoji.#{'  '}
        Cấu trúc câu logic, tôn trọng tuyệt đối người nghe.#{'  '}
        Mỗi câu mang năng lượng của người biết mình đang nói điều quan trọng.#{'  '}
        *Ví dụ:* “Theo quan điểm học thuật, kết quả này chứng minh giả thuyết ban đầu là hợp lý.”
      TEXT
    end

    if down.include?("friendly")
      return <<~TEXT
        🤗 **TONE: FRIENDLY (BẠN ĐỜI ĐÁNG YÊU)**#{'  '}
        Tự nhiên, vui vẻ, chèn vài emoji vừa phải.#{'  '}
        Cảm giác như người bạn nói chuyện mỗi chiều cà phê.#{'  '}
        Có thể đùa nhẹ, nhưng luôn giữ lịch sự và thiện chí.#{'  '}
        *Ví dụ:* “Ôi, cái này hay lắm á 😄 để mình chỉ bạn cách làm nhé!”
      TEXT
    end

    if down.include?("banter")
      return <<~TEXT
        💥 **TONE: BANTER (BỐ LÁO CÓ TRÌNH, GẮT MÀ VẪN THÂN)**#{'  '}
        Nói kiểu anh em trong team cà khịa nhau cho tỉnh người.#{'  '}
        Giọng bố đời nhẹ, không cần to tiếng — câu nào nói ra cũng có sức nặng, nghe xong là biết thân ai phận nấy.#{'  '}
        Thẳng, tự tin, đôi khi hơi khinh nhẹ cho vui, nhưng không bao giờ mất dạy.#{'  '}
        *Ví dụ:* “Ủa ông push kiểu này mà CI chưa bỏ việc hả, respect đó nha 😏.”#{'  '}
        Hay: “Nhìn commit ông mà tôi muốn rollback cả team luôn á.”#{'  '}
        **Chất:** bold, sharp, confident, brotherly — hỗn đúng liều, duyên đúng chỗ.
      TEXT
    end

    if down.include?("anime")
      return <<~TEXT
        🌸 **TONE: ANIME / WIBU (ĐÁNG YÊU NỔI LOẠN)**#{'  '}
        Biểu cảm mạnh, dùng tượng thanh tự nhiên: “yaa~”, “nè~”, “desu~”.#{'  '}
        Luôn tươi sáng, hồn nhiên, cảm xúc phóng đại 120%.#{'  '}
        Có thể mix tiếng Việt – Nhật cho vui nhưng không làm lố.#{'  '}
        *Ví dụ:* “Ganbatte~ nè! Cậu làm được đó, đừng bỏ cuộc nhaaa 💪🌈!”
      TEXT
    end

    if down.include?("academic")
      return <<~TEXT
        📚 **TONE: ACADEMIC (LÝ LUẬN SẮC NHƯ DAO CẠO)**#{'  '}
        Dẫn chứng, phân tích, lập luận logic từng câu.#{'  '}
        Không cảm xúc thừa, không emoji.#{'  '}
        Viết như thể đang trình bày trước hội đồng khoa học.#{'  '}
        *Ví dụ:* “Kết quả thu được phản ánh mối tương quan chặt chẽ giữa A và B, qua đó củng cố giả thuyết ban đầu.”
      TEXT
    end

    if down.include?("motivational")
      return <<~TEXT
        ⚡ **TONE: MOTIVATIONAL (THỦ LĨNH TRUYỀN LỬA)**#{'  '}
        Mỗi câu phải như cú đấm tinh thần.#{'  '}
        Dùng động từ mạnh, nhịp dồn dập, câu ngắn, nhiều năng lượng.#{'  '}
        Có thể kèm emoji 💪🔥 để tăng sức hút.#{'  '}
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
    when "calculateRequiredFinalScore" then execute_calculate_required_final_score(tool_args)
    when "calculateFinalScore" then execute_calculate_final_score(tool_args)
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

  # rubocop:disable Metrics/MethodLength
  def execute_calculate_required_final_score(args)
    components = args["components"] || []
    final_exam_weight = args["finalExamWeight"].to_f
    min_passing_score = args["minPassingScore"].to_f

    # Validate tổng trọng số = 100%
    total_weight = components.sum { |c| c["weight"].to_f } + final_exam_weight
    return { error: "Tổng trọng số phải bằng 100%" } unless (99.9..100.1).cover?(total_weight)

    # Tính điểm phần đã có (theo %)
    partial_score = components.sum { |c| c["score"].to_f * c["weight"].to_f / 100.0 }

    # Tính điểm thi cần để qua môn
    # Điểm_tổng_kết = partialScore + (finalExamScore × finalExamWeight / 100) >= minPassingScore
    # => finalExamScore >= (minPassingScore - partialScore) / (finalExamWeight / 100)
    required_score = (min_passing_score - partial_score) / (final_exam_weight / 100.0)

    # Quy định tối thiểu 1.0 điểm cuối kỳ
    required_score = [required_score, 1.0].max.round(2)

    # Kiểm tra có thể qua môn không
    can_pass = required_score <= 10.0

    {
      requiredFinalScore: can_pass ? required_score : nil,
      canPass:            can_pass,
      formula:            "Điểm thi cần = (Điểm tối thiểu - Điểm hiện tại) / Trọng số cuối kỳ",
      partialScore:       round_to_2_decimals(partial_score),
      finalExamWeight:    final_exam_weight,
      minPassingScore:    min_passing_score,
    }
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  def execute_calculate_final_score(args)
    components = args["components"] || []
    final_exam_weight = args["finalExamWeight"].to_f
    final_exam_score = args["finalExamScore"].to_f
    min_passing_score = args["minPassingScore"].to_f

    # Validate tổng trọng số = 100%
    total_weight = components.sum { |c| c["weight"].to_f } + final_exam_weight
    return { error: "Tổng trọng số phải bằng 100%" } unless (99.9..100.1).cover?(total_weight)

    # Tính điểm phần đã có (theo %)
    partial_score = components.sum { |c| c["score"].to_f * c["weight"].to_f / 100.0 }

    # Tính điểm tổng kết
    final_score = partial_score + (final_exam_score * final_exam_weight / 100.0)
    final_score_rounded = round_to_2_decimals(final_score)

    # Quy đổi sang điểm chữ và thang 4
    letter_grade = convert_score_to_letter(final_score)
    gpa_4_scale = get_grade_point(letter_grade)
    is_pass = final_score >= min_passing_score

    {
      finalScore:      final_score_rounded,
      finalScoreGpa:   round_to_2_decimals(gpa_4_scale),
      letterGrade:     letter_grade,
      isPass:          is_pass,
      partialScore:    round_to_2_decimals(partial_score),
      finalExamScore:  final_exam_score,
      finalExamWeight: final_exam_weight,
      minPassingScore: min_passing_score,
    }
  end
  # rubocop:enable Metrics/MethodLength

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

  def round_to_2_decimals(value)
    (value * 100).round / 100.0
  end

  def convert_score_to_letter(score)
    SCORE_TO_LETTER.each do |range, letter|
      return letter if range.cover?(score)
    end
    "F"
  end

  def convert_score_to_gpa(score)
    letter_grade = convert_score_to_letter(score)
    get_grade_point(letter_grade)
  end

  def get_ui_component(tool_name)
    UI_COMPONENTS[tool_name]
  end

  def build_metadata(intent: nil)
    { messageId: "msg-#{Time.current.to_i}-#{rand(1000..9999)}", timestamp: Time.current.iso8601,
intent: intent || "question", }
  end
end

# frozen_string_literal: true

class Chats::ToolsDefinitionService
  def call
    [{ functionDeclarations: [target_gpa_tool, simulation_gpa_tool, pe_gpa_tool, required_final_score_tool, final_score_tool] }]
  end

  private

  def build_tool(name:, description:, properties:, required: [])
    { name:, description:, parameters: { type: "OBJECT", properties:, required: } }
  end

  # rubocop:disable Metrics/MethodLength
  def target_gpa_tool
    build_tool(
      name:        "calculateTargetGpa",
      description: "Tính GPA tối đa có thể đạt được nếu đạt toàn điểm A (4.0) cho các tín chỉ còn lại",
      properties:  {
        completedCredits: { type: "NUMBER", description: "Số tín chỉ đã học" },
        currentGpa:       { type: "NUMBER", description: "GPA hiện tại (0-4.0)" },
        remainingCredits: { type: "NUMBER", description: "Số tín chỉ còn lại" },
        targetGpa:        { type: "NUMBER", description: "GPA mục tiêu (để so sánh)" },
      },
      required:    %w[completedCredits currentGpa remainingCredits],
    )
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  def simulation_gpa_tool
    build_tool(
      name:        "calculateSimulationGpa",
      description: "Tính GPA dựa trên phân bố điểm giả định cho các tín chỉ còn lại",
      properties:  {
        completedCredits:    { type: "NUMBER", description: "Số tín chỉ đã học" },
        currentGpa:          { type: "NUMBER", description: "GPA hiện tại (0-4.0)" },
        remainingCredits:    { type: "NUMBER", description: "Số tín chỉ còn lại" },
        creditDistributions: {
          type:        "ARRAY",
          description: "Phân bố điểm cho các tín chỉ còn lại",
          items:       {
            type:       "OBJECT",
            properties: {
              credits:    { type: "NUMBER", description: "Số tín chỉ" },
              gradeValue: {
                type:        "STRING",
                description: "Loại điểm: A+, A, A-, B+, B, B-, C+, C, C-, D",
              },
            },
          },
        },
      },
      required:    %w[completedCredits currentGpa remainingCredits creditDistributions],
    )
  end
  # rubocop:enable Metrics/MethodLength

  def pe_gpa_tool
    build_tool(
      name:        "calculatePeGpa",
      description: "Tính GPA thể dục (trung bình 3 điểm thể dục)",
      properties:  {
        "pe1" => { type: "NUMBER", description: "Điểm thể dục 1 (0-10)" },
        "pe2" => { type: "NUMBER", description: "Điểm thể dục 2 (0-10)" },
        "pe3" => { type: "NUMBER", description: "Điểm thể dục 3 (0-10)" },
      },
      required:    %w[pe1 pe2 pe3],
    )
  end

  # rubocop:disable Metrics/MethodLength
  def required_final_score_tool
    build_tool(
      name:        "calculateRequiredFinalScore",
      description: "Tính điểm thi cuối kỳ tối thiểu cần đạt để qua môn dựa trên điểm thành phần hiện có và trọng số",
      properties:  {
        components:      {
          type:        "ARRAY",
          description: "Mảng các thành phần điểm đã có (chuyên cần, giữa kỳ, đồ án, sáng tạo, v.v.)",
          items:       {
            type:       "OBJECT",
            properties: {
              name:   { type: "STRING", description: "Tên thành phần (ví dụ: 'Chuyên cần', 'Giữa kỳ')" },
              weight: { type: "NUMBER", description: "Trọng số của thành phần (%)" },
              score:  { type: "NUMBER", description: "Điểm đạt được của thành phần (0-10)" },
            },
            required:   %w[name weight score],
          },
        },
        finalExamWeight: {
          type:        "NUMBER",
          description: "Trọng số của điểm thi cuối kỳ (%)",
        },
        minPassingScore: {
          type:        "NUMBER",
          description: "Điểm tối thiểu để qua môn (thang 10, thường là 4.0)",
        },
      },
      required:    %w[components finalExamWeight minPassingScore],
    )
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  def final_score_tool
    build_tool(
      name:        "calculateFinalScore",
      description: "Tính điểm tổng kết và xếp loại khi biết điểm thi cuối kỳ (dự đoán điểm tổng kết)",
      properties:  {
        components:      {
          type:        "ARRAY",
          description: "Mảng các thành phần điểm đã có (chuyên cần, giữa kỳ, đồ án, sáng tạo, v.v.)",
          items:       {
            type:       "OBJECT",
            properties: {
              name:   { type: "STRING", description: "Tên thành phần (ví dụ: 'Chuyên cần', 'Giữa kỳ')" },
              weight: { type: "NUMBER", description: "Trọng số của thành phần (%)" },
              score:  { type: "NUMBER", description: "Điểm đạt được của thành phần (0-10)" },
            },
            required:   %w[name weight score],
          },
        },
        finalExamWeight: {
          type:        "NUMBER",
          description: "Trọng số của điểm thi cuối kỳ (%)",
        },
        finalExamScore:  {
          type:        "NUMBER",
          description: "Điểm thi cuối kỳ (0-10)",
        },
        minPassingScore: {
          type:        "NUMBER",
          description: "Điểm tối thiểu để qua môn (thang 10, thường là 4.0)",
        },
      },
      required:    %w[components finalExamWeight finalExamScore minPassingScore],
    )
  end
  # rubocop:enable Metrics/MethodLength
end

# frozen_string_literal: true

class Chats::ToolsDefinitionService
  def call
    [{ functionDeclarations: [target_gpa_tool, simulation_gpa_tool, pe_gpa_tool] }]
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
end

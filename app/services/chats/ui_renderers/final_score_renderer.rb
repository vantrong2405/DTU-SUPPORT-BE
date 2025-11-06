# frozen_string_literal: true

class Chats::UiRenderers::FinalScoreRenderer < Chats::UiRenderers::BaseRenderer
  def render(result)
    final_score = dig_value(result, :finalScore)
    final_gpa = dig_value(result, :finalScoreGpa)
    letter = dig_value(result, :letterGrade)
    is_pass = dig_value(result, :isPass)
    final_exam = dig_value(result, :finalExamScore)
    weight = dig_value(result, :finalExamWeight)
    min_pass = dig_value(result, :minPassingScore)

    badge = if is_pass
              "<span class=\"#{BADGES[:success]}\">Đạt môn</span>"
            else
              "<span class=\"#{BADGES[:warning]}\">Không đạt</span>"
            end

    <<~HTML.strip
      <div class="#{CONTAINER_CLASSES}">
        <div class="flex items-center gap-2">
          #{info_icon_svg}
          <div class="#{TITLE_CLASSES}">Điểm tổng kết & xếp loại</div>
        </div>

        <div class="mt-2 grid grid-cols-1 sm:grid-cols-3 gap-3">
          #{metric_box('Tổng kết (10)', fmt_gpa(final_score, digits: 2))}
          #{metric_box('Quy đổi GPA (4)', fmt_gpa(final_gpa, digits: 2))}
          #{metric_box('Điểm chữ', safe_text(letter))}
        </div>

        <div class="mt-3 flex items-center gap-2">#{badge}</div>

        <div class="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-3">
          #{metric_box('Điểm thi cuối kỳ', fmt_gpa(final_exam, digits: 2))}
          #{metric_box('Trọng số cuối kỳ (%)', safe_text(weight))}
          #{metric_box('Điểm qua môn', fmt_gpa(min_pass, digits: 2))}
        </div>
      </div>
    HTML
  end

  private

  def metric_box(label, value)
    <<~HTML
      <div class="rounded-md border border-border/30 bg-muted/40 p-3">
        <div class="text-[11px] text-muted-foreground">#{label}</div>
        <div class="text-lg font-semibold">#{value}</div>
      </div>
    HTML
  end
end

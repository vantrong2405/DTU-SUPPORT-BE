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
        <div class="flex items-center gap-2.5 mb-4">
          <div class="flex-shrink-0 p-1.5 rounded-lg bg-primary/10 ring-1 ring-primary/20">
            #{info_icon_svg}
          </div>
          <div class="#{TITLE_CLASSES}">Điểm tổng kết & xếp loại</div>
        </div>

        <div class="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-3">
          #{metric_box('Tổng kết (10)', fmt_gpa(final_score, digits: 2))}
          #{metric_box('Quy đổi GPA (4)', fmt_gpa(final_gpa, digits: 2))}
          #{metric_box('Điểm chữ', safe_text(letter))}
        </div>

        <div class="mt-4 flex items-center gap-2">#{badge}</div>

        <div class="mt-4 grid grid-cols-1 sm:grid-cols-3 gap-3">
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
      <div class="rounded-xl border border-border/40 bg-gradient-to-br from-muted/50 to-muted/30 p-4 break-words shadow-sm hover:shadow-md transition-shadow duration-200 ring-1 ring-border/20">
        <div class="text-[11px] font-medium text-muted-foreground/80 break-words mb-1.5 tracking-wide uppercase">#{label}</div>
        <div class="text-xl sm:text-2xl font-bold text-foreground break-words">#{value}</div>
      </div>
    HTML
  end
end

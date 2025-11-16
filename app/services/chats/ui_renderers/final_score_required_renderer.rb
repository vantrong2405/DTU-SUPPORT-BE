# frozen_string_literal: true

class Chats::UiRenderers::FinalScoreRequiredRenderer < Chats::UiRenderers::BaseRenderer
  def render(result)
    required = dig_value(result, :requiredFinalScore)
    can_pass = dig_value(result, :canPass)
    partial = dig_value(result, :partialScore)
    weight = dig_value(result, :finalExamWeight)
    min_pass = dig_value(result, :minPassingScore)

    badge = if can_pass
              "<span class=\"#{BADGES[:success]}\">Có thể qua môn</span>"
            else
              "<span class=\"#{BADGES[:warning]}\">Không thể qua môn</span>"
            end

    main_value = required.nil? ? "—" : fmt_gpa(required, digits: 2)

    <<~HTML.strip
      <div class="#{CONTAINER_CLASSES}">
        <div class="flex items-center gap-2.5 mb-4">
          <div class="flex-shrink-0 p-1.5 rounded-lg bg-primary/10 ring-1 ring-primary/20">
            #{info_icon_svg}
          </div>
          <div class="#{TITLE_CLASSES}">Điểm thi cuối kỳ cần đạt</div>
        </div>
        <div class="#{VALUE_CLASSES}">#{main_value}</div>
        <div class="mt-4 flex items-center gap-2">#{badge}</div>
        <div class="mt-4 grid grid-cols-1 sm:grid-cols-3 gap-3">
          #{metric_box('Điểm phần đã có', fmt_gpa(partial, digits: 2))}
          #{metric_box('Trọng số cuối kỳ (%)', safe_text(weight))}
          #{metric_box('Điểm qua môn', fmt_gpa(min_pass, digits: 2))}
        </div>
        <div class="mt-4 p-3 rounded-lg bg-muted/30 border border-border/30">
          <div class="text-xs #{SUBTEXT_CLASSES}">
            <span class="font-semibold">Công thức:</span> (Điểm tối thiểu - Điểm hiện tại) / (Trọng số cuối kỳ / 100)
          </div>
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

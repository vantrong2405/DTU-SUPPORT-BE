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
        <div class="flex items-center gap-2">
          #{info_icon_svg}
          <div class="#{TITLE_CLASSES}">Điểm thi cuối kỳ cần đạt</div>
        </div>
        <div class="#{VALUE_CLASSES}">#{main_value}</div>
        <div class="mt-3 flex items-center gap-2">#{badge}</div>
        <div class="mt-3 grid grid-cols-3 gap-3">
          #{metric_box('Điểm phần đã có', fmt_gpa(partial, digits: 2))}
          #{metric_box('Trọng số cuối kỳ (%)', safe_text(weight))}
          #{metric_box('Điểm qua môn', fmt_gpa(min_pass, digits: 2))}
        </div>
        <div class="mt-3 text-xs #{SUBTEXT_CLASSES}">Công thức: (Điểm tối thiểu - Điểm hiện tại) / (Trọng số cuối kỳ / 100)</div>
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

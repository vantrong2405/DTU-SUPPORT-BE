# frozen_string_literal: true

class Chats::UiRenderers::SimulationGpaRenderer < Chats::UiRenderers::BaseRenderer
  def render(result)
    final_gpa = dig_value(result, :finalGpa)
    remaining_gpa = dig_value(result, :remainingGpa)
    total_credits = dig_value(result, :totalCredits)
    distribution_summary = dig_value(result, :distributionSummary)
    classification = dig_value(result, :graduationClassification) || {}
    rank = dig_value(classification, :rank)

    <<~HTML.strip
      <div class="#{CONTAINER_CLASSES}">
        <div class="flex items-center gap-2">
          #{info_icon_svg}
          <div class="#{TITLE_CLASSES}">GPA giả định sau phân bố điểm</div>
        </div>

        <div class="mt-2 grid grid-cols-1 sm:grid-cols-3 gap-3">
          #{metric_box('GPA cuối', fmt_gpa(final_gpa))}
          #{metric_box('GPA phần còn lại', fmt_gpa(remaining_gpa))}
          #{metric_box('Tổng tín chỉ', safe_text(total_credits))}
        </div>

        <div class="mt-3 flex items-center gap-2">
          <span class="#{BADGES[:neutral]}">Xếp loại: #{rank_label(rank)}</span>
        </div>

        #{render_distribution(distribution_summary)}
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

  def render_distribution(summary)
    return "" if summary.to_s.strip.empty?
    items = summary.split(",").map(&:strip)
    list = items.map { |i| "<li class=\"leading-relaxed\">#{safe_text(i)}</li>" }.join
    <<~HTML
      <div class="mt-4">
        <div class="#{TITLE_CLASSES}">Phân bố điểm</div>
        <ul class="mt-1 list-disc pl-5 text-sm leading-relaxed">#{list}</ul>
      </div>
    HTML
  end

  def rank_label(rank)
    case rank.to_s
    when "excellent" then "Xuất sắc"
    when "good" then "Giỏi"
    when "fair" then "Khá"
    when "average" then "Trung bình"
    when "below_average" then "Yếu"
    else "—"
    end
  end
end

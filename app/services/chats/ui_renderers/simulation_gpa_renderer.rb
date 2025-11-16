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
        <div class="flex items-center gap-2.5 mb-4">
          <div class="flex-shrink-0 p-1.5 rounded-lg bg-primary/10 ring-1 ring-primary/20">
            #{info_icon_svg}
          </div>
          <div class="#{TITLE_CLASSES}">GPA giả định sau phân bố điểm</div>
        </div>

        <div class="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-3">
          #{metric_box('GPA cuối', fmt_gpa(final_gpa))}
          #{metric_box('GPA phần còn lại', fmt_gpa(remaining_gpa))}
          #{metric_box('Tổng tín chỉ', safe_text(total_credits))}
        </div>

        <div class="mt-4 flex items-center gap-2">
          <span class="#{BADGES[:neutral]}">Xếp loại: #{rank_label(rank)}</span>
        </div>

        #{render_distribution(distribution_summary)}
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

  def render_distribution(summary)
    return "" if summary.to_s.strip.empty?
    items = summary.split(",").map(&:strip)
    list = items.map { |i| "<li class=\"leading-relaxed break-words py-1\">#{safe_text(i)}</li>" }.join
    <<~HTML
      <div class="mt-5 p-4 rounded-xl bg-muted/30 border border-border/30">
        <div class="#{TITLE_CLASSES} mb-2">Phân bố điểm</div>
        <ul class="list-disc pl-5 text-sm leading-relaxed break-words space-y-1">#{list}</ul>
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

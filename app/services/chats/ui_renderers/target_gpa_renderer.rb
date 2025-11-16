# frozen_string_literal: true

class Chats::UiRenderers::TargetGpaRenderer < Chats::UiRenderers::BaseRenderer
  def render(result)
    max_gpa = dig_value(result, :maxGpaWithAllA)
    can_reach = dig_value(result, :canReachTarget)
    classification = dig_value(result, :graduationClassification) || {}
    rank = dig_value(classification, :rank)
    min_gpa = dig_value(classification, :minGpa)
    max_gpa_rank = dig_value(classification, :maxGpa)

    badge = build_badge(can_reach, rank)

    <<~HTML.strip
      <div class="#{CONTAINER_CLASSES}">
        <div class="flex items-center gap-2.5 mb-3">
          <div class="flex-shrink-0 p-1.5 rounded-lg bg-primary/10 ring-1 ring-primary/20">
            #{info_icon_svg}
          </div>
          <div class="#{TITLE_CLASSES}">GPA tối đa nếu đạt toàn A</div>
        </div>
        <div class="#{VALUE_CLASSES}">#{fmt_gpa(max_gpa)}</div>
        <div class="mt-4 flex flex-wrap items-center gap-2.5">
          #{badge}
          <div class="#{SUBTEXT_CLASSES}">#{render_range(rank, min_gpa, max_gpa_rank)}</div>
        </div>
        #{render_tips(can_reach)}
      </div>
    HTML
  end

  private

  def build_badge(can_reach, rank)
    return "<span class=\"#{BADGES[:success]}\">Có thể đạt mục tiêu</span>" if can_reach == true
    return "<span class=\"#{BADGES[:warning]}\">Khó đạt mục tiêu</span>" if can_reach == false
    "<span class=\"#{BADGES[:neutral]}\">#{rank_label(rank)}</span>"
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

  def render_range(rank, min_gpa, max_gpa)
    return "" if rank.nil? || min_gpa.nil? || max_gpa.nil?
    "Xếp loại: #{rank_label(rank)} (#{format('%.2f', min_gpa)}–#{format('%.2f', max_gpa)})"
  end

  def render_tips(can_reach)
    return "" if can_reach.nil?
    if can_reach
      <<~HTML
        <div class="mt-4 p-3 rounded-lg bg-emerald-500/5 border border-emerald-500/20">
          <div class="flex items-start gap-2">
            <svg class="h-4 w-4 text-emerald-600 dark:text-emerald-400 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div class="text-xs text-muted-foreground/90 leading-relaxed">
              <span class="font-semibold text-emerald-700 dark:text-emerald-300">Gợi ý:</span> Duy trì hiệu suất hiện tại và ưu tiên các học phần trọng số cao để tối ưu GPA.
            </div>
          </div>
        </div>
      HTML
    else
      <<~HTML
        <div class="mt-4 p-3 rounded-lg bg-amber-500/5 border border-amber-500/20">
          <div class="flex items-start gap-2">
            <svg class="h-4 w-4 text-amber-600 dark:text-amber-400 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <div class="text-xs text-muted-foreground/90 leading-relaxed">
              <span class="font-semibold text-amber-700 dark:text-amber-300">Gợi ý:</span> Xem lại phân bố học phần, cân nhắc giảm tải hoặc cải thiện ở môn nền tảng để kéo GPA.
            </div>
          </div>
        </div>
      HTML
    end
  end
end

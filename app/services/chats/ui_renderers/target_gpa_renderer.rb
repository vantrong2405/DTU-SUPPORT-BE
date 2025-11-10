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
        <div class="flex items-center gap-2">
          #{info_icon_svg}
          <div class="#{TITLE_CLASSES}">GPA tối đa nếu đạt toàn A</div>
        </div>
        <div class="#{VALUE_CLASSES}">#{fmt_gpa(max_gpa)}</div>
        <div class="mt-3 flex items-center gap-2">
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
        <div class="mt-3 text-xs text-muted-foreground">
          Gợi ý: Duy trì hiệu suất hiện tại và ưu tiên các học phần trọng số cao để tối ưu GPA.
        </div>
      HTML
    else
      <<~HTML
        <div class="mt-3 text-xs text-muted-foreground">
          Gợi ý: Xem lại phân bố học phần, cân nhắc giảm tải hoặc cải thiện ở môn nền tảng để kéo GPA.
        </div>
      HTML
    end
  end
end

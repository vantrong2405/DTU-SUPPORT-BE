# frozen_string_literal: true

class Chats::UiRenderers::PeGpaRenderer < Chats::UiRenderers::BaseRenderer
  def render(result)
    average = dig_value(result, :average)
    is_pass = dig_value(result, :isPass)
    inputs = dig_value(result, :inputs) || {}
    <<~HTML.strip
      <div class="#{CONTAINER_CLASSES}">
        <div class="flex items-center gap-2">
          #{info_icon_svg}
          <div class="#{TITLE_CLASSES}">GPA Thể dục (TB cộng 3 điểm)</div>
        </div>
        <div class="#{VALUE_CLASSES}">#{fmt_gpa(average, digits: 2)}</div>
        <div class="mt-3 flex items-center gap-2">
          #{build_status_badge(is_pass)}
          <div class="#{SUBTEXT_CLASSES}">Điểm tối thiểu để qua: 2.00</div>
        </div>
        #{render_inputs_grid(inputs)}
      </div>
    HTML
  end

  private

  def build_status_badge(is_pass)
    return "<span class=\"#{BADGES[:success]}\">Qua môn</span>" if is_pass
    "<span class=\"#{BADGES[:warning]}\">Chưa đạt</span>"
  end

  def render_inputs_grid(inputs)
    <<~HTML
      <div class="mt-3 grid grid-cols-3 gap-2 text-center">
        #{pe_box('PE1', dig_value(inputs, 'pe1'))}
        #{pe_box('PE2', dig_value(inputs, 'pe2'))}
        #{pe_box('PE3', dig_value(inputs, 'pe3'))}
      </div>
    HTML
  end

  def pe_box(label, value)
    <<~HTML
      <div class="rounded-md border border-border/30 bg-muted/40 p-2">
        <div class="text-[11px] text-muted-foreground">#{label}</div>
        <div class="text-xl font-semibold tracking-tight">#{fmt_gpa(value, digits: 2)}</div>
      </div>
    HTML
  end
end

# frozen_string_literal: true

class Chats::UiRenderers::BaseRenderer
  CONTAINER_CLASSES = [
    "rounded-xl border border-border/20 bg-card/95",
    "backdrop-blur supports-[backdrop-filter]:bg-card/80",
    "text-card-foreground p-4 shadow-sm",
  ].join(" ")
  TITLE_CLASSES = "text-sm font-medium text-muted-foreground"
  VALUE_CLASSES = "mt-1 text-3xl font-semibold tracking-tight text-primary"
  SUBTEXT_CLASSES = "text-xs text-muted-foreground"

  BADGES = {
    success: [
      "inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium",
      "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300",
      "border border-emerald-500/20",
    ].join(" "),
    warning: [
      "inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium",
      "bg-amber-500/10 text-amber-700 dark:text-amber-300",
      "border border-amber-500/20",
    ].join(" "),
    neutral: "inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-muted text-muted-foreground border border-border/40",
  }.freeze

  def safe_text(value)
    value.to_s
  end

  def fmt_gpa(value, digits: 3)
    return "—" if value.nil?
    format("%.#{digits}f", value.to_f)
  end

  def dig_value(hash, key)
    return nil unless hash.is_a?(Hash)
    hash[key] || hash[key.to_s]
  end

  def info_icon_svg(class_names = "h-4 w-4 text-muted-foreground")
    <<~SVG.strip
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" class="#{class_names}">
        <circle cx="12" cy="12" r="10" stroke-width="1.5"></circle>
        <path d="M12 8h.01" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path>
        <path d="M11 12h1v4h1" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"></path>
      </svg>
    SVG
  end
end

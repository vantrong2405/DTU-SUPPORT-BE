# frozen_string_literal: true

class Chats::UiRenderers::BaseRenderer
  CONTAINER_CLASSES = [
    "w-full max-w-full rounded-2xl border border-border/30",
    "bg-gradient-to-br from-card via-card/95 to-card/90",
    "backdrop-blur-sm supports-[backdrop-filter]:backdrop-blur-md",
    "text-card-foreground p-5 sm:p-6 shadow-lg",
    "ring-1 ring-border/20 overflow-hidden",
    "transition-all duration-200 hover:shadow-xl",
  ].join(" ")
  TITLE_CLASSES = "text-sm font-semibold text-muted-foreground/90 break-words tracking-wide"
  VALUE_CLASSES = "mt-2 text-3xl sm:text-4xl font-bold tracking-tight text-primary break-words"
  SUBTEXT_CLASSES = "text-xs text-muted-foreground/80 break-words leading-relaxed"

  BADGES = {
    success: [
      "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
      "bg-gradient-to-r from-emerald-500/15 to-emerald-500/10",
      "text-emerald-700 dark:text-emerald-300",
      "border border-emerald-500/30 shadow-sm",
      "backdrop-blur-sm transition-all duration-200",
    ].join(" "),
    warning: [
      "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
      "bg-gradient-to-r from-amber-500/15 to-amber-500/10",
      "text-amber-700 dark:text-amber-300",
      "border border-amber-500/30 shadow-sm",
      "backdrop-blur-sm transition-all duration-200",
    ].join(" "),
    neutral: [
      "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
      "bg-gradient-to-r from-muted/60 to-muted/40",
      "text-muted-foreground border border-border/50",
      "shadow-sm backdrop-blur-sm transition-all duration-200",
    ].join(" "),
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

  def info_icon_svg(class_names = "h-5 w-5 text-primary/70")
    <<~SVG.strip
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" class="#{class_names}" stroke-width="2">
        <circle cx="12" cy="12" r="10"></circle>
        <path d="M12 8v4" stroke-linecap="round" stroke-linejoin="round"></path>
        <path d="M12 16h.01" stroke-linecap="round" stroke-linejoin="round"></path>
      </svg>
    SVG
  end
end

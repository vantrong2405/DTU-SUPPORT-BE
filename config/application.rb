# frozen_string_literal: true

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DtuSupportBe
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Set default locale to English
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:vi, :en, :ja]

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, key: "_dtu_support_session", expire_after: 1.week

    config.secrets = ActiveSupport::OrderedOptions.new
    secrets_file = Rails.root.join("config", "secrets.yml")
    if secrets_file.exist?
      secrets = YAML.load(ERB.new(secrets_file.read).result, aliases: true)[Rails.env]
      config.secrets.merge!(secrets.deep_symbolize_keys) if secrets
    end

    # Make secrets accessible via Rails.application.secrets
    def self.secrets
      config.secrets
    end
  end
end

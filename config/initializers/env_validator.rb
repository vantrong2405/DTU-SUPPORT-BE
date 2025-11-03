# frozen_string_literal: true

# Validates that all required environment variables from .env.example
# are present in environment-specific .env file (.env.development, .env.staging, .env.production)
class EnvValidator
  ENV_FILE = {
    production:  ".env.production",
    staging:     ".env.staging",
    development: ".env.development",
    example:     ".env.example",
  }.freeze

  NODE_ENV = {
    production: "production",
    staging:    "staging",
  }.freeze

  def validate!
    required_keys = extract_keys_from_file(ENV_FILE[:example])
    return if required_keys.empty?

    env_file = get_env_file_name
    existing_keys = extract_keys_from_file(env_file)
    missing_keys = required_keys - existing_keys

    return if missing_keys.empty?

    missing = missing_keys.join(", ")
    message = "Missing required environment variables in #{env_file}: #{missing}"
    Rails.logger&.error(message)
    raise message
  end

  private

  def get_env_file_name
    node_env = Rails.env

    return ENV_FILE[:production] if node_env == NODE_ENV[:production]
    return ENV_FILE[:staging] if node_env == NODE_ENV[:staging] || node_env == "test"

    ENV_FILE[:development]
  end

  def extract_keys_from_file(filename)
    path = Rails.root.join(filename)

    begin
      content = File.read(path)
      parse_env_keys(content)
    rescue Errno::ENOENT
      if filename == ENV_FILE[:example]
        raise ".env.example file not found."
      end

      env_file = get_env_file_name
      raise <<~ERROR
        #{env_file} file not found. Please copy .env.example to #{env_file} and fill in the values.
      ERROR
    end
  end

  def parse_env_keys(content)
    content.split("\n")
           .map(&:strip)
           .reject { |line| line.empty? || line.start_with?("#") }
           .filter_map { |line| line.match(/^([A-Z_][A-Z0-9_]*)=/)&.[](1) }
  end
end

# Execute validation after Rails has initialized
Rails.application.config.after_initialize do
  EnvValidator.new.validate!
end

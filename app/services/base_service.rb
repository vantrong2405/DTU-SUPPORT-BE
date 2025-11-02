class Services::BaseService
  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs).call(&block)
  end

  def call
    raise NotImplementedError, "Subclasses must implement #call"
  end

  protected

  def supabase_client
    @supabase_client ||= Supabase.new
  end

  def supabase_rest_url
    "#{Rails.application.secrets.supabase[:url]}/rest/v1"
  end

  def supabase_auth_url
    "#{Rails.application.secrets.supabase[:url]}/auth/v1"
  end
end

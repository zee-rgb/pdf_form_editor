# Supabase configuration for Rails
# This initializer sets up the Supabase client for storage and other services

if Rails.env.production? || ENV["SUPABASE_URL"].present?
  require "net/http"
  require "uri"

  class SupabaseClient
    attr_reader :url, :anon_key, :service_role_key

    def initialize
      @url = ENV.fetch("SUPABASE_URL") { raise "SUPABASE_URL not set" }
      @anon_key = ENV.fetch("SUPABASE_ANON_KEY") { raise "SUPABASE_ANON_KEY not set" }
      @service_role_key = ENV["SUPABASE_SERVICE_ROLE_KEY"]
    end

    def storage_url
      "#{@url}/storage/v1"
    end

    def rest_url
      "#{@url}/rest/v1"
    end

    def auth_url
      "#{@url}/auth/v1"
    end
  end

  # Initialize global Supabase client
  Rails.application.config.supabase = SupabaseClient.new

  Rails.logger.info "Supabase configured for #{Rails.env} environment"
else
  Rails.logger.info "Supabase not configured - using local storage in #{Rails.env}"
end

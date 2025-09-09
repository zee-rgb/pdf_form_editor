require "net/http"
require "uri"
require "json"

# Custom Active Storage service for Supabase Storage
class SupabaseService < ActiveStorage::Service
  attr_reader :url, :key, :bucket
  
  def initialize(url:, key:, bucket:)
    @url = url
    @key = key
    @bucket = bucket
  end
  
  def upload(key, io, checksum: nil, content_type: nil, disposition: nil, filename: nil, custom_metadata: {})
    instrument :upload, key: key, checksum: checksum do
      uri = URI("#{storage_url}/object/#{bucket}/#{key}")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@key}"
      request["Content-Type"] = content_type || "application/octet-stream"
      request.body = io.read
      
      response = http.request(request)
      
      unless response.is_a?(Net::HTTPSuccess)
        raise ActiveStorage::IntegrityError, "Failed to upload file: #{response.body}"
      end
      
      io.rewind if io.respond_to?(:rewind)
    end
  end
  
  def download(key, &block)
    if block_given?
      instrument :streaming_download, key: key do
        stream(key, &block)
      end
    else
      instrument :download, key: key do
        uri = URI("#{storage_url}/object/#{bucket}/#{key}")
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{@key}"
        
        response = http.request(request)
        
        if response.is_a?(Net::HTTPSuccess)
          response.body
        else
          raise ActiveStorage::FileNotFoundError, "File not found: #{key}"
        end
      end
    end
  end
  
  def download_chunk(key, range)
    instrument :download_chunk, key: key, range: range do
      uri = URI("#{storage_url}/object/#{bucket}/#{key}")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@key}"
      request["Range"] = "bytes=#{range.begin}-#{range.exclude_end? ? range.end - 1 : range.end}"
      
      response = http.request(request)
      
      if response.is_a?(Net::HTTPPartialContent)
        response.body
      else
        raise ActiveStorage::FileNotFoundError, "File not found: #{key}"
      end
    end
  end
  
  def delete(key)
    instrument :delete, key: key do
      uri = URI("#{storage_url}/object/#{bucket}/#{key}")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Delete.new(uri)
      request["Authorization"] = "Bearer #{@key}"
      
      response = http.request(request)
      
      # Supabase returns 200 for successful deletion
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn "Failed to delete file from Supabase: #{key} - #{response.body}"
      end
    end
  end
  
  def delete_prefixed(prefix)
    instrument :delete_prefixed, prefix: prefix do
      # List objects with prefix and delete them
      keys = list_objects(prefix)
      keys.each { |key| delete(key) }
    end
  end
  
  def exist?(key)
    instrument :exist, key: key do |payload|
      uri = URI("#{storage_url}/object/#{bucket}/#{key}")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Head.new(uri)
      request["Authorization"] = "Bearer #{@key}"
      
      response = http.request(request)
      answer = response.is_a?(Net::HTTPSuccess)
      payload[:exist] = answer
      answer
    end
  rescue => e
    Rails.logger.warn "Error checking file existence: #{e.message}"
    false
  end
  
  def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
    instrument :url, key: key do |payload|
      generated_url = "#{storage_url}/object/#{bucket}/#{key}"
      payload[:url] = generated_url
      generated_url
    end
  end
  
  def headers_for_direct_upload(key, content_type:, checksum:, filename: nil, disposition: nil, custom_metadata: {})
    {
      "Authorization" => "Bearer #{@key}",
      "Content-Type" => content_type
    }
  end
  
  def url(key, expires_in: nil, filename: nil, disposition: :inline, content_type: nil)
    instrument :url, key: key do |payload|
      # For public access, construct direct URL
      generated_url = "#{storage_url}/object/public/#{bucket}/#{key}"
      payload[:url] = generated_url
      generated_url
    end
  end
  
  private
  
  def storage_url
    "#{@url}/storage/v1"
  end
  
  def stream(key)
    uri = URI("#{storage_url}/object/#{bucket}/#{key}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@key}"
    
    http.request(request) do |response|
      if response.is_a?(Net::HTTPSuccess)
        response.read_body do |chunk|
          yield chunk
        end
      else
        raise ActiveStorage::FileNotFoundError, "File not found: #{key}"
      end
    end
  end
  
  def list_objects(prefix)
    # This would require implementing the Supabase Storage list API
    # For now, return empty array
    []
  end
end

# frozen_string_literal: true

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Include Devise test helpers
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Warden::Test::Helpers

  # Configure Devise for testing
  config.before(:suite) do
    Warden.test_mode!
  end

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Clean up uploaded files during tests
  config.after(:each) do
    if defined?(ActiveStorage) && ActiveStorage::Blob.service.respond_to?(:root)
      FileUtils.rm_rf(ActiveStorage::Blob.service.root) if File.exist?(ActiveStorage::Blob.service.root)
    end
    Warden.test_reset!
  end
end

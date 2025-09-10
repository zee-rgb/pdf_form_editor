# Configure Active Storage to use Supabase in production environment
if Rails.env.production?
  Rails.application.config.active_storage.service = :supabase
elsif Rails.env.test?
  Rails.application.config.active_storage.service = :test
else
  Rails.application.config.active_storage.service = :local
end

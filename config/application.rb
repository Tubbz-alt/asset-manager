require_relative 'boot'

require "rails"
# Pick the frameworks you want:
# require "active_model/railtie"
# require "active_job/railtie"
# require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
# require "action_view/railtie"
# require "action_cable/engine"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AssetManager
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Disable Rack::Cache
    config.action_dispatch.rack_cache = nil

    config.assets.prefix = "/asset-manager"

    unless Rails.application.secrets.jwt_auth_secret
      raise "JWT auth secret is not configured. See config/secrets.yml"
    end
  end

  mattr_accessor :govuk

  mattr_accessor :s3

  mattr_accessor :carrier_wave_store_base_dir

  mattr_accessor :content_disposition
  mattr_accessor :default_content_type

  mattr_accessor :fake_s3
end

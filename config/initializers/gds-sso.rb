GDS::SSO.config do |config|
  config.user_model   = "User"
  config.oauth_id     = ENV["OAUTH_ID"] || "abcdefghjasndjkasndassetmanager"
  config.oauth_secret = ENV["OAUTH_SECRET"] || "secret"
  config.oauth_root_url = Plek.new.external_url_for("signon")
  config.cache = Rails.cache
end

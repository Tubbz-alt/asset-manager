AssetManager.aws_s3_bucket_name = ENV['AWS_S3_BUCKET_NAME']
AssetManager.stream_all_assets_from_s3 = ENV['STREAM_ALL_ASSETS_FROM_S3'].present?
AssetManager.redirect_all_asset_requests_to_s3 = ENV['REDIRECT_ALL_ASSET_REQUESTS_TO_S3'].present?
AssetManager.aws_s3_use_virtual_host = ENV['AWS_S3_USE_VIRTUAL_HOST'].present?

Aws.config.update(
  logger: Rails.logger
)
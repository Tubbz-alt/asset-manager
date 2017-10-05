namespace :govuk_assets do
  desc 'Store values generated from file metadata for all GOV.UK assets'
  task store_values_generated_from_file_metadata: :environment do
    STDOUT.sync = true
    assets = Asset.all
    total = assets.count
    assets.each_with_index do |asset, index|
      percent = "%0.0f" % (index / total.to_f * 100)
      if (index % 1000).zero?
        puts "#{index} of #{total} (#{percent}%) assets queued"
      end
      AssetFileMetadataWorker.perform_async(asset.id)
    end
    puts "\nFinished!"
  end
end

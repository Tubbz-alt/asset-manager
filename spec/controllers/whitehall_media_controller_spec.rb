require "rails_helper"

RSpec.describe WhitehallMediaController, type: :controller do
  shared_examples 'redirects to placeholders' do
    before do
      allow(asset).to receive(:image?).and_return(image)
    end

    context 'and asset is image' do
      let(:image) { true }

      it 'redirects to thumbnail-placeholder image' do
        get :download, params: { path: path, format: format }

        expect(controller).to redirect_to(described_class.helpers.image_path('thumbnail-placeholder.png'))
      end
    end

    context 'and asset is not an image' do
      let(:image) { false }

      it 'redirects to government placeholder page' do
        get :download, params: { path: path, format: format }

        expect(controller).to redirect_to('/government/placeholder')
      end
    end
  end

  describe '#download' do
    let(:path) { 'path/to/asset' }
    let(:format) { 'png' }
    let(:legacy_url_path) { "/government/uploads/#{path}.#{format}" }
    let(:draft) { false }
    let(:redirect_url) { nil }
    let(:attributes) {
      {
        legacy_url_path: legacy_url_path,
        state: state,
        draft: draft,
        redirect_url: redirect_url
      }
    }
    let(:asset) { FactoryBot.build(:whitehall_asset, attributes) }

    before do
      allow(WhitehallAsset).to receive(:find_by).with(legacy_url_path: legacy_url_path).and_return(asset)
    end

    context 'when asset is uploaded' do
      let(:state) { 'uploaded' }

      it "proxies asset to S3 via Nginx" do
        expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

        get :download, params: { path: path, format: format }
      end

      context 'and legacy_url_path has no format' do
        let(:legacy_url_path) { "/government/uploads/#{path}" }

        it "proxies asset to S3 via Nginx" do
          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, params: { path: path, format: nil }
        end
      end
    end

    context 'when asset is draft and uploaded' do
      let(:draft) { true }
      let(:state) { 'uploaded' }
      let(:draft_assets_host) { AssetManager.govuk.draft_assets_host }

      context 'when requested from host other than draft-assets' do
        before do
          request.headers['X-Forwarded-Host'] = "not-#{draft_assets_host}"
        end

        it 'redirects to draft assets host' do
          get :download, params: { path: path, format: format }

          expect(controller).to redirect_to(host: draft_assets_host, path: path, format: format)
        end
      end

      context 'when requested from draft-assets host' do
        before do
          request.headers['X-Forwarded-Host'] = draft_assets_host
          allow(controller).to receive(:authenticate_user!)
          allow(controller).to receive(:proxy_to_s3_via_nginx)
        end

        it 'requires authentication' do
          expect(controller).to receive(:authenticate_user!)

          get :download, params: { path: path, format: format }
        end

        it 'proxies asset to S3 via Nginx as usual' do
          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, params: { path: path, format: format }
        end

        it "sets Cache-Control header to no-cache" do
          get :download, params: { path: path, format: format }

          expect(response.headers["Cache-Control"]).to eq("no-cache")
        end
      end
    end

    context 'when asset has a redirect URL' do
      let(:state) { 'uploaded' }
      let(:redirect_url) { 'https://example.com/path/file.ext' }

      it 'redirects to redirect URL' do
        get :download, params: { path: path, format: format }

        expect(response).to redirect_to(redirect_url)
      end
    end

    context 'when asset has a replacement' do
      let(:state) { 'uploaded' }
      let(:replacement) { FactoryBot.create(:uploaded_asset) }

      before do
        asset.replacement = replacement
      end

      it 'redirects to replacement for asset' do
        get :download, params: { path: path, format: format }

        expect(response).to redirect_to(replacement.public_url_path)
      end

      it 'responds with 301 moved permanently status' do
        get :download, params: { path: path, format: format }

        expect(response).to have_http_status(:moved_permanently)
      end

      it 'sets the Cache-Control response header to 24 hours' do
        get :download, params: { path: path, format: format }

        expect(response.headers['Cache-Control']).to eq('max-age=86400, public')
      end

      context 'and the replacement is draft' do
        before do
          replacement.update_attribute(:draft, true)
        end

        it 'serves the original asset when requested via something other than the draft-assets host' do
          request.headers['X-Forwarded-Host'] = "not-#{AssetManager.govuk.draft_assets_host}"

          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, params: { path: path, format: format }
        end

        it 'redirects to the replacement asset when requested via the draft-assets host by a signed-in user' do
          request.headers['X-Forwarded-Host'] = AssetManager.govuk.draft_assets_host
          allow(controller).to receive(:authenticate_user!)

          get :download, params: { path: path, format: format }

          expect(response).to redirect_to(replacement.public_url_path)
        end
      end
    end

    context 'when asset is draft and access limited' do
      let(:user) { FactoryBot.build(:user) }
      let(:state) { 'uploaded' }

      before do
        allow(controller).to receive(:proxy_to_s3_via_nginx)
        allow(WhitehallAsset).to receive(:from_params).and_return(asset)
        request.headers['X-Forwarded-Host'] = AssetManager.govuk.draft_assets_host
        login_as user
      end

      it 'grants access to a user who is authorised to view the asset' do
        allow(asset).to receive(:accessible_by?).with(user).and_return(true)

        get :download, params: { path: path, format: format }

        expect(response).to be_success
      end

      it 'denies access to a user who is not authorised to view the asset' do
        allow(asset).to receive(:accessible_by?).with(user).and_return(false)

        get :download, params: { path: path, format: format }

        expect(response).to be_forbidden
      end
    end

    context "when the asset doesn't contain a parent_document_url" do
      let(:state) { 'uploaded' }

      before do
        allow(controller).to receive(:proxy_to_s3_via_nginx)
        allow(WhitehallAsset).to receive(:from_params).and_return(asset)
        asset.update_attribute(:parent_document_url, nil)
      end

      it "doesn't send a Link HTTP header" do
        get :download, params: { path: path, format: format }

        expect(response.headers['Link']).to be_nil
      end
    end

    context 'when the asset has a parent_document_url' do
      let(:state) { 'uploaded' }

      before do
        allow(controller).to receive(:proxy_to_s3_via_nginx)
        allow(WhitehallAsset).to receive(:from_params).and_return(asset)
        asset.update_attribute(:parent_document_url, 'parent-document-url')
      end

      it 'sends the parent_document_url in a Link HTTP header' do
        get :download, params: { path: path, format: format }

        expect(response.headers['Link']).to eql('<parent-document-url>; rel="up"')
      end
    end

    context 'when asset is unscanned' do
      let(:state) { 'unscanned' }

      include_examples 'redirects to placeholders'
    end

    context 'when asset is clean' do
      let(:state) { 'clean' }

      include_examples 'redirects to placeholders'
    end

    context 'when asset is infected' do
      let(:state) { 'infected' }

      it 'responds with 404 Not Found' do
        get :download, params: { path: path, format: format }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with a soft deleted file' do
      let(:state) { 'uploaded' }

      before do
        allow(WhitehallAsset).to receive(:find_by).with(legacy_url_path: legacy_url_path).and_return(nil)
        asset.update_attribute(:deleted_at, Time.now)
      end

      it 'responds with not found status' do
        get :download, params: { path: path, format: format }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

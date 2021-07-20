require 'rails_helper'

RSpec.describe Admin::ExportDomainBlocksController, type: :controller do
  render_views

  before do
    sign_in Fabricate(:user, admin: true), scope: :user
  end

  describe 'GET #export' do
    it 'renders instances' do
      Fabricate(:domain_block, domain: 'bad.domain', severity: 'silence', public_comment: 'bad')
      Fabricate(:domain_block, domain: 'worse.domain', severity: 'suspend', reject_media: true, reject_reports: true, public_comment: 'worse', obfuscate: true)
      Fabricate(:domain_block, domain: 'reject.media', severity: 'noop', reject_media: true, public_comment: 'reject media')
      Fabricate(:domain_block, domain: 'no.op', severity: 'noop', public_comment: 'noop')

      get :export, params: { format: :csv }
      expect(response).to have_http_status(200)
      expect(response.body).to eq(IO.read(File.join(file_fixture_path, 'domain_blocks.csv')))
    end
  end

  describe 'POST #import' do
    it 'blocks imported domains' do
      allow(DomainBlockWorker).to receive(:perform_async).and_return(true)

      post :import, params: { admin_import: { data: fixture_file_upload('domain_blocks.csv') } }

      expect(response).to redirect_to(admin_instances_path(limited: '1'))
      expect(DomainBlockWorker).to have_received(:perform_async).exactly(3).times

      # Header should not be imported
      expect(DomainBlock.where(domain: '#domain').present?).to eq(false)

      # Domains should now be added
      get :export, params: { format: :csv }
      expect(response).to have_http_status(200)
      expect(response.body).to eq(IO.read(File.join(file_fixture_path, 'domain_blocks.csv')))
    end
  end

  it 'displays error on no file selected' do
    post :import, params: { admin_import: {} }
    expect(response).to redirect_to(admin_instances_path(limited: '1'))
    expect(flash[:error]).to eq(I18n.t('admin.export_domain_blocks.no_file'))
  end
end

require 'rails_helper'

RSpec.describe Admin::ExportDomainAllowsController, type: :controller do
  render_views

  before do
    sign_in Fabricate(:user, admin: true), scope: :user
  end

  describe 'GET #export' do
    it 'renders instances' do
      Fabricate(:domain_allow, domain: 'good.domain')
      Fabricate(:domain_allow, domain: 'better.domain')

      get :export, params: { format: :csv }
      expect(response).to have_http_status(200)
      expect(response.body).to eq(IO.read(File.join(file_fixture_path, 'domain_allows.csv')))
    end
  end

  describe 'POST #import' do
    it 'allows imported domains' do
      post :import, params: { admin_import: { data: fixture_file_upload('domain_allows.csv') } }

      expect(response).to redirect_to(admin_instances_path)

      # Header should not be imported
      expect(DomainAllow.where(domain: '#domain').present?).to eq(false)

      # Domains should now be added
      get :export, params: { format: :csv }
      expect(response).to have_http_status(200)
      expect(response.body).to eq(IO.read(File.join(file_fixture_path, 'domain_allows.csv')))
    end

    it 'displays error on no file selected' do
      post :import, params: { admin_import: {} }
      expect(response).to redirect_to(admin_instances_path)
      expect(flash[:error]).to eq(I18n.t('admin.export_domain_allows.no_file'))
    end
  end
end

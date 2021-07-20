require 'rails_helper'

RSpec.describe Admin::DomainAllowsController, type: :controller do
  render_views

  before do
    sign_in Fabricate(:user, admin: true), scope: :user
  end

  describe 'GET #new' do
    it 'assigns a new domain allow' do
      get :new

      expect(assigns(:domain_allow)).to be_instance_of(DomainAllow)
      expect(response).to have_http_status(200)
    end
  end

  describe 'POST #create' do
    it 'blocks the domain when succeeded to save' do
      post :create, params: { domain_allow: { domain: 'example.com' } }

      expect(flash[:notice]).to eq I18n.t('admin.domain_allows.created_msg')
      expect(response).to redirect_to(admin_instances_path)
    end

    it 'renders new when failed to save' do
      Fabricate(:domain_allow, domain: 'example.com')

      post :create, params: { domain_allow: { domain: 'example.com' } }

      expect(response).to render_template :new
    end
  end

  describe 'DELETE #destroy' do
    it 'disallows the domain' do
      service = double(call: true)
      allow(UnallowDomainService).to receive(:new).and_return(service)
      domain_allow = Fabricate(:domain_allow)
      delete :destroy, params: { id: domain_allow.id }

      expect(service).to have_received(:call).with(domain_allow)
      expect(flash[:notice]).to eq I18n.t('admin.domain_allows.destroyed_msg')
      expect(response).to redirect_to(admin_instances_path)
    end
  end
end

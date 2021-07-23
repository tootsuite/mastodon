# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::RegistrationFiltersController, type: :controller do
  render_views

  before do
    sign_in Fabricate(:user, admin: true), scope: :user
  end

  describe 'GET #index' do
    around do |example|
      default_per_page = RegistrationFilter.default_per_page
      RegistrationFilter.paginates_per 1
      example.run
      RegistrationFilter.paginates_per default_per_page
    end

    it 'renders registration filters' do
      2.times { Fabricate(:registration_filter) }

      get :index, params: { page: 2 }

      assigned = assigns(:registration_filters)
      expect(assigned.count).to eq 1
      expect(assigned.klass).to be RegistrationFilter
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET #new' do
    it 'assigns a new registration filter' do
      get :new

      expect(assigns(:registration_filter)).to be_instance_of(RegistrationFilter)
      expect(response).to have_http_status(200)
    end
  end

  describe 'POST #create' do
    it 'returns to registration filters page when succeeded to save' do
      post :create, params: { registration_filter: { phrase: 'bitcoin' } }

      expect(flash[:notice]).to eq I18n.t('admin.registration_filters.created_msg')
      expect(response).to redirect_to(admin_registration_filters_path)
    end
  end

  describe 'DELETE #destroy' do
    it 'returns to registration filters page when succeeded destroying' do
      registration_filter = Fabricate(:registration_filter)
      delete :destroy, params: { id: registration_filter.id }

      expect(flash[:notice]).to eq I18n.t('admin.registration_filters.destroyed_msg')
      expect(response).to redirect_to(admin_registration_filters_path)
    end
  end
end

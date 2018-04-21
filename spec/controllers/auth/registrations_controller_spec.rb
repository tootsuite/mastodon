require 'rails_helper'

RSpec.describe Auth::RegistrationsController, type: :controller do
  render_views

  shared_examples 'checks for enabled registrations' do |path|
    around do |example|
      open_registrations = Setting.open_registrations
      example.run
      Setting.open_registrations = open_registrations
    end

    it 'redirects if it is in single user mode while it is open for registration' do
      Fabricate(:account)
      Setting.open_registrations = true
      expect(Rails.configuration.x).to receive(:single_user_mode).and_return(true)

      get path

      expect(response).to redirect_to '/'
    end

    it 'redirects if it is not open for registration while it is not in single user mode' do
      Setting.open_registrations = false
      expect(Rails.configuration.x).to receive(:single_user_mode).and_return(false)

      get path

      expect(response).to redirect_to '/'
    end
  end

  describe 'GET #edit' do
    it 'returns http success' do
      request.env["devise.mapping"] = Devise.mappings[:user]
      sign_in(Fabricate(:user))
      get :edit
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET #update' do
    it 'returns http success' do
      request.env["devise.mapping"] = Devise.mappings[:user]
      sign_in(Fabricate(:user), scope: :user)
      post :update
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET #new' do
    before do
      request.env["devise.mapping"] = Devise.mappings[:user]
    end

    context do
      around do |example|
        open_registrations = Setting.open_registrations
        example.run
        Setting.open_registrations = open_registrations
      end

      it 'returns http success' do
        Setting.open_registrations = true
        get :new
        expect(response).to have_http_status(200)
      end
    end

    include_examples 'checks for enabled registrations', :new
  end

  describe 'POST #create' do
    let(:accept_language) { Rails.application.config.i18n.available_locales.sample.to_s }

    before { request.env["devise.mapping"] = Devise.mappings[:user] }

    context do
      around do |example|
        open_registrations = Setting.open_registrations
        example.run
        Setting.open_registrations = open_registrations
      end

      subject do
        Setting.open_registrations = true
        request.headers["Accept-Language"] = accept_language
        post :create, params: { user: { account_attributes: { username: 'test' }, email: 'test@example.com', password: '12345678', password_confirmation: '12345678' } }
      end

      it 'redirects to login page' do
        subject
        expect(response).to redirect_to new_user_session_path
      end

      it 'creates user' do
        subject
        user = User.find_by(email: 'test@example.com')
        expect(user).to_not be_nil
        expect(user.locale).to eq(accept_language)
      end
    end

    it 'does nothing if user already exists' do
      Fabricate(:user, account: Fabricate(:account, username: 'test'))
      subject
    end

    include_examples 'checks for enabled registrations', :create
  end

  describe 'DELETE #destroy' do
    let(:user) { Fabricate(:user) }

    before do
      request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in(user, scope: :user)
      delete :destroy
    end

    it 'returns http not found' do
      expect(response).to have_http_status(:not_found)
    end

    it 'does not delete user' do
      expect(User.find(user.id)).to_not be_nil
    end
  end
end

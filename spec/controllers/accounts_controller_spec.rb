require 'rails_helper'

RSpec.describe AccountsController, type: :controller do
  render_views

  let(:alice)  { Fabricate(:account, username: 'alice') }

  describe 'GET #show' do
    before do
      status1 = Status.create!(account: alice, text: 'Hello world')
      Status.create!(account: alice, text: 'Boop', thread: status1)
      status3 = Status.create!(account: alice, text: 'Picture!')
      status3.media_attachments.create!(account: alice, file: fixture_file_upload('files/attachment.jpg', 'image/jpeg'))
      Status.create!(account: alice, text: 'Mentioning @alice')
    end

    context 'atom' do
      before do
        get :show, params: { username: alice.username }, format: 'atom'
      end

      it 'returns http success with Atom' do
        expect(response).to have_http_status(:success)
      end
    end

    context 'activitystreams2' do
      before do
        get :show, params: { username: alice.username }, format: 'activitystreams2'
      end

      it 'returns http success with Activity Streams 2.0' do
        expect(response).to have_http_status(:success)
      end
    end

    context 'html' do
      before do
        get :show, params: { username: alice.username }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns an h-entry for each status in the h-feed' do
        expect(Nokogiri::HTML(response.body).search('.h-feed .h-entry').size).to eq 4
      end
    end
  end

  describe 'GET #followers' do
    it 'returns http success' do
      get :followers, params: { username: alice.username }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #following' do
    it 'returns http success' do
      get :following, params: { username: alice.username }
      expect(response).to have_http_status(:success)
    end
  end
end

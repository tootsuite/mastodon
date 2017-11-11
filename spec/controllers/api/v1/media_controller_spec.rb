require 'rails_helper'

RSpec.describe Api::V1::MediaController, type: :controller do
  render_views

  let(:user)  { Fabricate(:user, account: Fabricate(:account, username: 'alice')) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'write') }

  before do
    allow(controller).to receive(:doorkeeper_token) { token }
  end

  describe 'POST #create' do
    describe 'with paperclip errors' do
      context 'when graphicsmagick cant identify the file type' do
        before do
          expect_any_instance_of(Account).to receive_message_chain(:media_attachments, :create!).and_raise(Paperclip::Errors::NotIdentifiedByImageMagickError)
          post :create, params: { file: fixture_file_upload('files/attachment.jpg', 'image/jpeg') }
        end

        it 'returns http 422' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'when there is a generic error' do
        before do
          expect_any_instance_of(Account).to receive_message_chain(:media_attachments, :create!).and_raise(Paperclip::Error)
          post :create, params: { file: fixture_file_upload('files/attachment.jpg', 'image/jpeg') }
        end

        it 'returns http 422' do
          expect(response).to have_http_status(:error)
        end
      end
    end

    context 'image/jpeg' do
      before do
        post :create, params: { file: fixture_file_upload('files/attachment.jpg', 'image/jpeg') }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'creates a media attachment' do
        expect(MediaAttachment.first).to_not be_nil
      end

      it 'uploads a file' do
        expect(MediaAttachment.first).to have_attached_file(:file)
      end

      it 'returns media ID in JSON' do
        expect(body_as_json[:id]).to eq MediaAttachment.first.id.to_s
      end
    end

    context 'image/gif' do
      before do
        post :create, params: { file: fixture_file_upload('files/attachment.gif', 'image/gif') }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'creates a media attachment' do
        expect(MediaAttachment.first).to_not be_nil
      end

      it 'uploads a file' do
        expect(MediaAttachment.first).to have_attached_file(:file)
      end

      it 'returns media ID in JSON' do
        expect(body_as_json[:id]).to eq MediaAttachment.first.id.to_s
      end
    end

    context 'video/webm' do
      before do
        post :create, params: { file: fixture_file_upload('files/attachment.webm', 'video/webm') }
      end

      xit 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      xit 'creates a media attachment' do
        expect(MediaAttachment.first).to_not be_nil
      end

      xit 'uploads a file' do
        expect(MediaAttachment.first).to have_attached_file(:file)
      end

      xit 'returns media ID in JSON' do
        expect(body_as_json[:id]).to eq MediaAttachment.first.id.to_s
      end
    end
  end

  describe 'PUT #update' do
    context 'when somebody else\'s' do
      let(:media) { Fabricate(:media_attachment, status: nil) }

      it 'returns http not found' do
        put :update, params: { id: media.id, description: 'Lorem ipsum!!!' }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not attached to a status' do
      let(:media) { Fabricate(:media_attachment, status: nil, account: user.account) }

      it 'updates the description' do
        put :update, params: { id: media.id, description: 'Lorem ipsum!!!' }
        expect(media.reload.description).to eq 'Lorem ipsum!!!'
      end
    end

    context 'when attached to a status' do
      let(:media) { Fabricate(:media_attachment, status: Fabricate(:status), account: user.account) }

      it 'returns http not found' do
        put :update, params: { id: media.id, description: 'Lorem ipsum!!!' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

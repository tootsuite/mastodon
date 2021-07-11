# frozen_string_literal: true

require 'rails_helper'

describe PermalinkRedirector do
  describe '#redirect_url' do
    before do
      account = Fabricate(:account, username: 'alice', id: 1)
      Fabricate(:status, account: account, id: 123)
    end

    it 'returns path for legacy account links' do
      redirector = described_class.new('web/accounts/1')
      expect(redirector.redirect_path).to eq 'https://cb6e6126.ngrok.io/@alice'
    end

    it 'returns path for legacy status links' do
      redirector = described_class.new('web/statuses/123')
      expect(redirector.redirect_path).to eq 'https://cb6e6126.ngrok.io/@alice/123'
    end

    it 'returns path for legacy tag links' do
      redirector = described_class.new('web/timelines/tag/hoge')
      expect(redirector.redirect_path).to eq '/tags/hoge'
    end

    it 'returns path for pretty account links' do
      redirector = described_class.new('web/@alice')
      expect(redirector.redirect_path).to eq 'https://cb6e6126.ngrok.io/@alice'
    end

    it 'returns path for pretty status links' do
      redirector = described_class.new('web/@alice/123')
      expect(redirector.redirect_path).to eq 'https://cb6e6126.ngrok.io/@alice/123'
    end

    it 'returns path for pretty tag links' do
      redirector = described_class.new('web/tags/hoge')
      expect(redirector.redirect_path).to eq '/tags/hoge'
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

describe InviteRequestValidator do
  let!(:whole_word_filter) { Fabricate(:registration_filter, phrase: 'whole-word', type: :text, whole_word: true) }
  let!(:not_whole_word)    { Fabricate(:registration_filter, phrase: 'find-it-anywhere', type: :text, whole_word: false) }
  let!(:regexp_filter)     { Fabricate(:registration_filter, phrase: 'https://.*/.*\.exe', type: :regexp) }
  let(:invite_request)     { double(text: request_text, persisted?: false, errors: double(add: nil)) }

  describe '#validate' do
    context 'when invite request text does not match any filter' do
      let(:request_text)    { 'I am just a prospective new user wanting to try out Mastodon. My website is https://allaboutbitcoin.org/' }

      it 'does not add any error' do
        subject.validate(invite_request)
        expect(invite_request.errors).to_not have_received(:add)
      end
    end

    context 'when middle of invite request text matches whole-word filter' do
      let(:request_text) { 'I like Whole-word so much!' }

      it 'adds an error' do
        subject.validate(invite_request)
        expect(invite_request.errors).to have_received(:add)
      end
    end

    context 'when start of invite request text matches whole-word filter' do
      let(:request_text) { 'Whole-word is great!' }

      it 'adds an error' do
        subject.validate(invite_request)
        expect(invite_request.errors).to have_received(:add)
      end
    end

    context 'when end of invite request text matches whole-word filter' do
      let(:request_text) { 'I will tell you all about Whole-word' }

      it 'adds an error' do
        subject.validate(invite_request)
        expect(invite_request.errors).to have_received(:add)
      end
    end

    context 'when middle of invite request text matches non-whole-word filter' do
      let(:request_text) { 'dontthinkyoucanfind-it-anywherehere' }

      it 'adds an error' do
        subject.validate(invite_request)
        expect(invite_request.errors).to have_received(:add)
      end
    end

    context 'when start of invite request text matches non-whole-word filter' do
      let(:request_text) { 'find-it-anywhereifyouwish' }

      it 'adds an error' do
        subject.validate(invite_request)
        expect(invite_request.errors).to have_received(:add)
      end
    end

    context 'when end of invite request text matches non-whole-word filter' do
      let(:request_text) { 'cantfind-it-anywhere' }

      it 'adds an error' do
        subject.validate(invite_request)
        expect(invite_request.errors).to have_received(:add)
      end
    end

    context 'when middle of invite request text matches regexp filter' do
      let(:request_text) { 'check out my website at https://foo.bar/pwned.exe it is dank' }

      it 'adds an error' do
        subject.validate(invite_request)
        expect(invite_request.errors).to have_received(:add)
      end
    end

    context 'when start of invite request text matches regexp filter' do
      let(:request_text) { 'https://foo.bar/pwned.exe is so dank check it out' }

      it 'adds an error' do
        subject.validate(invite_request)
        expect(invite_request.errors).to have_received(:add)
      end
    end

    context 'when end of invite request text matches regexp filter' do
      let(:request_text) { 'check out my website at https://foo.bar/pwned.exe' }

      it 'adds an error' do
        subject.validate(invite_request)
        expect(invite_request.errors).to have_received(:add)
      end
    end
  end
end

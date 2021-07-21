require 'rails_helper'

RSpec.describe ActivityPub::FetchRemoteAccountService, type: :service do
  subject { ActivityPub::FetchRemoteAccountService.new }

  let!(:actor) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: 'https://example.com/alice',
      type: 'Person',
      preferredUsername: 'alice',
      name: 'Alice',
      summary: 'Foo bar',
      inbox: 'http://example.com/alice/inbox',
    }
  end

  describe '#call' do
    let(:account) { subject.call('https://example.com/alice', id: true) }

    shared_examples 'sets profile data' do
      it 'returns an account' do
        expect(account).to be_an Account
      end

      it 'sets display name' do
        expect(account.display_name).to eq 'Alice'
      end

      it 'sets note' do
        expect(account.note).to eq 'Foo bar'
      end

      it 'sets URL' do
        expect(account.url).to eq 'https://example.com/alice'
      end
    end

    context 'when the account does not have a inbox' do
      let!(:webfinger) { { subject: 'acct:alice@example.com', links: [{ rel: 'self', href: 'https://example.com/alice' }] } }

      before do
        actor[:inbox] = nil

        stub_request(:get, 'https://example.com/alice').to_return(body: Oj.dump(actor))
        stub_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:alice@example.com').to_return(body: Oj.dump(webfinger), headers: { 'Content-Type': 'application/jrd+json' })
      end

      it 'fetches resource' do
        account
        expect(a_request(:get, 'https://example.com/alice')).to have_been_made.once
      end

      it 'looks up webfinger' do
        account
        expect(a_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:alice@example.com')).to have_been_made.once
      end

      it 'returns nil' do
        expect(account).to be_nil
      end
    end

    context 'when URI and WebFinger share the same host' do
      let!(:webfinger) { { subject: 'acct:alice@example.com', links: [{ rel: 'self', href: 'https://example.com/alice' }] } }

      before do
        stub_request(:get, 'https://example.com/alice').to_return(body: Oj.dump(actor))
        stub_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:alice@example.com').to_return(body: Oj.dump(webfinger), headers: { 'Content-Type': 'application/jrd+json' })
      end

      it 'fetches resource' do
        account
        expect(a_request(:get, 'https://example.com/alice')).to have_been_made.once
      end

      it 'looks up webfinger' do
        account
        expect(a_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:alice@example.com')).to have_been_made.once
      end

      it 'sets username and domain from webfinger' do
        expect(account.username).to eq 'alice'
        expect(account.domain).to eq 'example.com'
      end

      include_examples 'sets profile data'
    end

    context 'when WebFinger presents different domain than URI' do
      let!(:webfinger) { { subject: 'acct:alice@iscool.af', links: [{ rel: 'self', href: 'https://example.com/alice' }] } }

      before do
        stub_request(:get, 'https://example.com/alice').to_return(body: Oj.dump(actor))
        stub_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:alice@example.com').to_return(body: Oj.dump(webfinger), headers: { 'Content-Type': 'application/jrd+json' })
        stub_request(:get, 'https://iscool.af/.well-known/webfinger?resource=acct:alice@iscool.af').to_return(body: Oj.dump(webfinger), headers: { 'Content-Type': 'application/jrd+json' })
      end

      it 'fetches resource' do
        account
        expect(a_request(:get, 'https://example.com/alice')).to have_been_made.once
      end

      it 'looks up webfinger' do
        account
        expect(a_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:alice@example.com')).to have_been_made.once
      end

      it 'looks up "redirected" webfinger' do
        account
        expect(a_request(:get, 'https://iscool.af/.well-known/webfinger?resource=acct:alice@iscool.af')).to have_been_made.once
      end

      it 'sets username and domain from final webfinger' do
        expect(account.username).to eq 'alice'
        expect(account.domain).to eq 'iscool.af'
      end

      include_examples 'sets profile data'
    end

    context 'when WebFinger returns a different URI' do
      let!(:webfinger) { { subject: 'acct:alice@example.com', links: [{ rel: 'self', href: 'https://example.com/bob' }] } }

      before do
        stub_request(:get, 'https://example.com/alice').to_return(body: Oj.dump(actor))
        stub_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:alice@example.com').to_return(body: Oj.dump(webfinger), headers: { 'Content-Type': 'application/jrd+json' })
      end

      it 'fetches resource' do
        account
        expect(a_request(:get, 'https://example.com/alice')).to have_been_made.once
      end

      it 'looks up webfinger' do
        account
        expect(a_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:alice@example.com')).to have_been_made.once
      end

      it 'does not create account' do
        expect(account).to be_nil
      end
    end

    context 'when WebFinger returns a different URI after a redirection' do
      let!(:webfinger) { { subject: 'acct:alice@iscool.af', links: [{ rel: 'self', href: 'https://example.com/bob' }] } }

      before do
        stub_request(:get, 'https://example.com/alice').to_return(body: Oj.dump(actor))
        stub_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:alice@example.com').to_return(body: Oj.dump(webfinger), headers: { 'Content-Type': 'application/jrd+json' })
        stub_request(:get, 'https://iscool.af/.well-known/webfinger?resource=acct:alice@iscool.af').to_return(body: Oj.dump(webfinger), headers: { 'Content-Type': 'application/jrd+json' })
      end

      it 'fetches resource' do
        account
        expect(a_request(:get, 'https://example.com/alice')).to have_been_made.once
      end

      it 'looks up webfinger' do
        account
        expect(a_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:alice@example.com')).to have_been_made.once
      end

      it 'looks up "redirected" webfinger' do
        account
        expect(a_request(:get, 'https://iscool.af/.well-known/webfinger?resource=acct:alice@iscool.af')).to have_been_made.once
      end

      it 'does not create account' do
        expect(account).to be_nil
      end
    end

    context 'with wrong id' do
      it 'does not create account' do
        expect(subject.call('https://fake.address/@foo', prefetched_body: Oj.dump(actor))).to be_nil
      end
    end
  end
end

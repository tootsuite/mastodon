require 'rails_helper'

RSpec.describe ResolveAccountService, type: :service do
  subject { described_class.new }

  before do
    stub_request(:get, "https://example.com/.well-known/host-meta").to_return(status: 404)
    stub_request(:get, "https://quitter.no/avatar/7477-300-20160211190340.png").to_return(request_fixture('avatar.txt'))
    stub_request(:get, "https://ap.example.com/.well-known/webfinger?resource=acct:foo@ap.example.com").to_return(request_fixture('activitypub-webfinger.txt'))
    stub_request(:get, "https://ap.example.com/users/foo").to_return(request_fixture('activitypub-actor.txt'))
    stub_request(:get, "https://ap.example.com/users/foo.atom").to_return(request_fixture('activitypub-feed.txt'))
    stub_request(:get, %r{https://ap.example.com/users/foo/\w+}).to_return(status: 404)
    stub_request(:get, 'https://example.com/.well-known/webfinger?resource=acct:hoge@example.com').to_return(status: 410)
  end

  context 'using skip_webfinger' do
    context 'when account is known' do
      let!(:remote_account) { Fabricate(:account, username: 'foo', domain: 'ap.example.com', protocol: 'activitypub') }

      context 'when domain is banned' do
        let!(:domain_block) { Fabricate(:domain_block, domain: 'ap.example.com', severity: :suspend) }

        it 'does not return an account' do
          expect(subject.call('foo@ap.example.com', skip_webfinger: true)).to be_nil
        end

        it 'does not make a webfinger query' do
          subject.call('foo@ap.example.com', skip_webfinger: true)
          expect(a_request(:get, 'https://ap.example.com/.well-known/webfinger?resource=acct:foo@ap.example.com')).to_not have_been_made
        end
      end

      context 'when domain is not banned' do
        it 'returns the expected account' do
          expect(subject.call('foo@ap.example.com', skip_webfinger: true)).to eq remote_account
        end

        it 'does not make a webfinger query' do
          subject.call('foo@ap.example.com', skip_webfinger: true)
          expect(a_request(:get, 'https://ap.example.com/.well-known/webfinger?resource=acct:foo@ap.example.com')).to_not have_been_made
        end
      end
    end

    context 'when account is not known' do
      it 'does not return an account' do
        expect(subject.call('foo@ap.example.com', skip_webfinger: true)).to be_nil
      end

      it 'does not make a webfinger query' do
        subject.call('foo@ap.example.com', skip_webfinger: true)
        expect(a_request(:get, 'https://ap.example.com/.well-known/webfinger?resource=acct:foo@ap.example.com')).to_not have_been_made
      end
    end
  end

  context 'when there is an LRDD endpoint but no resolvable account' do
    before do
      stub_request(:get, "https://quitter.no/.well-known/host-meta").to_return(request_fixture('.host-meta.txt'))
      stub_request(:get, "https://quitter.no/.well-known/webfinger?resource=acct:catsrgr8@quitter.no").to_return(status: 404)
    end

    it 'returns nil' do
      expect(subject.call('catsrgr8@quitter.no')).to be_nil
    end
  end

  context 'when there is no LRDD endpoint nor resolvable account' do
    before do
      stub_request(:get, "https://example.com/.well-known/webfinger?resource=acct:catsrgr8@example.com").to_return(status: 404)
    end

    it 'returns nil' do
      expect(subject.call('catsrgr8@example.com')).to be_nil
    end
  end

  context 'when webfinger returns http gone' do
    context 'for a previously known account' do
      before do
        Fabricate(:account, username: 'hoge', domain: 'example.com', last_webfingered_at: nil)
        allow(AccountDeletionWorker).to receive(:perform_async)
      end

      it 'returns nil' do
        expect(subject.call('hoge@example.com')).to be_nil
      end

      it 'queues account deletion worker' do
        subject.call('hoge@example.com')
        expect(AccountDeletionWorker).to have_received(:perform_async)
      end
    end

    context 'for a previously unknown account' do
      it 'returns nil' do
        expect(subject.call('hoge@example.com')).to be_nil
      end
    end
  end

  context 'with a legitimate webfinger redirection' do
    before do
      webfinger = { subject: 'acct:foo@ap.example.com', links: [{ rel: 'self', href: 'https://ap.example.com/users/foo', type: 'application/activity+json' }] }
      stub_request(:get, 'https://redirected.example.com/.well-known/webfinger?resource=acct:Foo@redirected.example.com').to_return(body: Oj.dump(webfinger), headers: { 'Content-Type': 'application/jrd+json' })
    end

    it 'returns new remote account' do
      account = subject.call('Foo@redirected.example.com')

      expect(account.activitypub?).to eq true
      expect(account.acct).to eq 'foo@ap.example.com'
      expect(account.inbox_url).to eq 'https://ap.example.com/users/foo/inbox'
    end
  end

  context 'with a misconfigured redirection' do
    before do
      webfinger = { subject: 'acct:Foo@redirected.example.com', links: [{ rel: 'self', href: 'https://ap.example.com/users/foo', type: 'application/activity+json' }] }
      stub_request(:get, 'https://redirected.example.com/.well-known/webfinger?resource=acct:Foo@redirected.example.com').to_return(body: Oj.dump(webfinger), headers: { 'Content-Type': 'application/jrd+json' })
    end

    it 'returns new remote account' do
      account = subject.call('Foo@redirected.example.com')

      expect(account.activitypub?).to eq true
      expect(account.acct).to eq 'foo@ap.example.com'
      expect(account.inbox_url).to eq 'https://ap.example.com/users/foo/inbox'
    end
  end

  context 'with too many webfinger redirections' do
    before do
      webfinger = { subject: 'acct:foo@evil.example.com', links: [{ rel: 'self', href: 'https://ap.example.com/users/foo', type: 'application/activity+json' }] }
      stub_request(:get, 'https://redirected.example.com/.well-known/webfinger?resource=acct:Foo@redirected.example.com').to_return(body: Oj.dump(webfinger), headers: { 'Content-Type': 'application/jrd+json' })
      webfinger2 = { subject: 'acct:foo@ap.example.com', links: [{ rel: 'self', href: 'https://ap.example.com/users/foo', type: 'application/activity+json' }] }
      stub_request(:get, 'https://evil.example.com/.well-known/webfinger?resource=acct:foo@evil.example.com').to_return(body: Oj.dump(webfinger2), headers: { 'Content-Type': 'application/jrd+json' })
    end

    it 'does not return a new remote account' do
      expect(subject.call('Foo@redirected.example.com')).to be_nil
    end
  end

  context 'with an ActivityPub account' do
    it 'returns new remote account' do
      account = subject.call('foo@ap.example.com')

      expect(account.activitypub?).to eq true
      expect(account.domain).to eq 'ap.example.com'
      expect(account.inbox_url).to eq 'https://ap.example.com/users/foo/inbox'
    end

    context 'with multiple types' do
      before do
        stub_request(:get, "https://ap.example.com/users/foo").to_return(request_fixture('activitypub-actor-individual.txt'))
      end

      it 'returns new remote account' do
        account = subject.call('foo@ap.example.com')

        expect(account.activitypub?).to eq true
        expect(account.domain).to eq 'ap.example.com'
        expect(account.inbox_url).to eq 'https://ap.example.com/users/foo/inbox'
        expect(account.actor_type).to eq 'Person'
      end
    end
  end

  context 'with an already-known actor changing acct: URI' do
    let!(:duplicate) { Fabricate(:account, username: 'foo', domain: 'old.example.com', uri: 'https://ap.example.com/users/foo') }
    let!(:status)    { Fabricate(:status, account: duplicate, text: 'foo') }

    it 'returns new remote account' do
      account = subject.call('foo@ap.example.com')

      expect(account.activitypub?).to eq true
      expect(account.domain).to eq 'ap.example.com'
      expect(account.inbox_url).to eq 'https://ap.example.com/users/foo/inbox'
      expect(account.uri).to eq 'https://ap.example.com/users/foo'
    end

    it 'merges accounts' do
      account = subject.call('foo@ap.example.com')

      expect(status.reload.account_id).to eq account.id
      expect(Account.where(uri: account.uri).count).to eq 1
    end
  end

  context 'with an already-known acct: URI changing ActivityPub id' do
    let!(:old_account) { Fabricate(:account, username: 'foo', domain: 'ap.example.com', uri: 'https://old.example.com/users/foo', last_webfingered_at: nil) }
    let!(:status)    { Fabricate(:status, account: old_account, text: 'foo') }

    it 'returns new remote account' do
      account = subject.call('foo@ap.example.com')

      expect(account.activitypub?).to eq true
      expect(account.domain).to eq 'ap.example.com'
      expect(account.inbox_url).to eq 'https://ap.example.com/users/foo/inbox'
      expect(account.uri).to eq 'https://ap.example.com/users/foo'
    end
  end

  it 'processes one remote account at a time using locks' do
    wait_for_start = true
    fail_occurred  = false
    return_values  = Concurrent::Array.new

    # Preload classes that throw circular dependency errors in threads
    Account
    TagManager
    DomainBlock

    threads = Array.new(5) do
      Thread.new do
        true while wait_for_start

        begin
          return_values << described_class.new.call('foo@ap.example.com')
        rescue ActiveRecord::RecordNotUnique
          fail_occurred = true
        end
      end
    end

    wait_for_start = false
    threads.each(&:join)

    expect(fail_occurred).to be false
    expect(return_values).to_not include(nil)
  end
end

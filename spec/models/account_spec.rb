require 'rails_helper'

RSpec.describe Account, type: :model do
  context do
    let(:bob) { Fabricate(:account, username: 'bob') }
    subject { Fabricate(:account) }

    describe '#follow!' do
      it 'creates a follow' do
        follow = subject.follow!(bob)

        expect(follow).to be_instance_of Follow
        expect(follow.account).to eq subject
        expect(follow.target_account).to eq bob
      end
    end

    describe '#unfollow!' do
      before do
        subject.follow!(bob)
      end

      it 'destroys a follow' do
        unfollow = subject.unfollow!(bob)

        expect(unfollow).to be_instance_of Follow
        expect(unfollow.account).to eq subject
        expect(unfollow.target_account).to eq bob
        expect(unfollow.destroyed?).to be true
      end
    end

    describe '#following?' do
      it 'returns true when the target is followed' do
        subject.follow!(bob)
        expect(subject.following?(bob)).to be true
      end

      it 'returns false if the target is not followed' do
        expect(subject.following?(bob)).to be false
      end
    end
  end

  describe '#local?' do
    it 'returns true when the account is local' do
      account = Fabricate(:account, domain: nil)
      expect(account.local?).to be true
    end

    it 'returns false when the account is on a different domain' do
      account = Fabricate(:account, domain: 'foreign.tld')
      expect(account.local?).to be false
    end
  end

  describe 'Local domain user methods' do
    around do |example|
      before = Rails.configuration.x.local_domain
      example.run
      Rails.configuration.x.local_domain = before
    end

    subject { Fabricate(:account, domain: nil, username: 'alice') }

    describe '#to_webfinger_s' do
      it 'returns a webfinger string for the account' do
        Rails.configuration.x.local_domain = 'example.com'

        expect(subject.to_webfinger_s).to eq 'acct:alice@example.com'
      end
    end

    describe '#local_username_and_domain' do
      it 'returns the username and local domain for the account' do
        Rails.configuration.x.local_domain = 'example.com'

        expect(subject.local_username_and_domain).to eq 'alice@example.com'
      end
    end
  end

  describe '#acct' do
    it 'returns username for local users' do
      account = Fabricate(:account, domain: nil, username: 'alice')
      expect(account.acct).to eql 'alice'
    end

    it 'returns username@domain for foreign users' do
      account = Fabricate(:account, domain: 'foreign.tld', username: 'alice')
      expect(account.acct).to eql 'alice@foreign.tld'
    end
  end

  describe '#save_with_optional_media!' do
    before do
      stub_request(:get, 'https://remote.test/valid_avatar').to_return(request_fixture('avatar.txt'))
      stub_request(:get, 'https://remote.test/invalid_avatar').to_return(request_fixture('feed.txt'))
    end

    let(:account) do
      Fabricate(:account,
                avatar_remote_url: 'https://remote.test/valid_avatar',
                header_remote_url: 'https://remote.test/valid_avatar')
    end

    let!(:expectation) { account.dup }

    context 'with valid properties' do
      before do
        account.save_with_optional_media!
      end

      it 'unchanges avatar, header, avatar_remote_url, and header_remote_url' do
        expect(account.avatar_remote_url).to eq expectation.avatar_remote_url
        expect(account.header_remote_url).to eq expectation.header_remote_url
        expect(account.avatar_file_name).to  eq expectation.avatar_file_name
        expect(account.header_file_name).to  eq expectation.header_file_name
      end
    end

    context 'with invalid properties' do
      before do
        account.avatar_remote_url = 'https://remote.test/invalid_avatar'
        account.save_with_optional_media!
      end

      it 'sets default avatar, header, avatar_remote_url, and header_remote_url' do
        expect(account.avatar_remote_url).to eq 'https://remote.test/invalid_avatar'
        expect(account.header_remote_url).to eq expectation.header_remote_url
        expect(account.avatar_file_name).to  eq nil
        expect(account.header_file_name).to  eq nil
      end
    end
  end

  describe '#possibly_stale?' do
    let(:account) { Fabricate(:account, last_webfingered_at: last_webfingered_at) }

    context 'last_webfingered_at is nil' do
      let(:last_webfingered_at) { nil }

      it 'returns true' do
        expect(account.possibly_stale?).to be true
      end
    end

    context 'last_webfingered_at is more than 24 hours before' do
      let(:last_webfingered_at) { 25.hours.ago }

      it 'returns true' do
        expect(account.possibly_stale?).to be true
      end
    end

    context 'last_webfingered_at is less than 24 hours before' do
      let(:last_webfingered_at) { 23.hours.ago }

      it 'returns false' do
        expect(account.possibly_stale?).to be false
      end
    end
  end

  describe '#refresh!' do
    let(:account) { Fabricate(:account, domain: domain) }
    let(:acct)    { account.acct }

    context 'domain is nil' do
      let(:domain) { nil }

      it 'returns nil' do
        expect(account.refresh!).to be_nil
      end

      it 'calls not ResolveAccountService#call' do
        expect_any_instance_of(ResolveAccountService).not_to receive(:call).with(acct)
        account.refresh!
      end
    end

    context 'domain is present' do
      let(:domain) { 'example.com' }

      it 'calls ResolveAccountService#call' do
        expect_any_instance_of(ResolveAccountService).to receive(:call).with(acct).once
        account.refresh!
      end
    end
  end

  describe '#to_param' do
    it 'returns username' do
      account = Fabricate(:account, username: 'alice')
      expect(account.to_param).to eq 'alice'
    end
  end

  describe '#keypair' do
    it 'returns an RSA key pair' do
      account = Fabricate(:account)
      expect(account.keypair).to be_instance_of OpenSSL::PKey::RSA
    end
  end

  describe '#object_type' do
    it 'is always a person' do
      account = Fabricate(:account)
      expect(account.object_type).to be :person
    end
  end

  describe '#favourited?' do
    let(:original_status) do
      author = Fabricate(:account, username: 'original')
      Fabricate(:status, account: author)
    end

    subject { Fabricate(:account) }

    context 'when the status is a reblog of another status' do
      let(:original_reblog) do
        author = Fabricate(:account, username: 'original_reblogger')
        Fabricate(:status, reblog: original_status, account: author)
      end

      it 'is is true when this account has favourited it' do
        Fabricate(:favourite, status: original_reblog, account: subject)

        expect(subject.favourited?(original_status)).to eq true
      end

      it 'is false when this account has not favourited it' do
        expect(subject.favourited?(original_status)).to eq false
      end
    end

    context 'when the status is an original status' do
      it 'is is true when this account has favourited it' do
        Fabricate(:favourite, status: original_status, account: subject)

        expect(subject.favourited?(original_status)).to eq true
      end

      it 'is false when this account has not favourited it' do
        expect(subject.favourited?(original_status)).to eq false
      end
    end
  end

  describe '#reblogged?' do
    let(:original_status) do
      author = Fabricate(:account, username: 'original')
      Fabricate(:status, account: author)
    end

    subject { Fabricate(:account) }

    context 'when the status is a reblog of another status' do
      let(:original_reblog) do
        author = Fabricate(:account, username: 'original_reblogger')
        Fabricate(:status, reblog: original_status, account: author)
      end

      it 'is true when this account has reblogged it' do
        Fabricate(:status, reblog: original_reblog, account: subject)

        expect(subject.reblogged?(original_reblog)).to eq true
      end

      it 'is false when this account has not reblogged it' do
        expect(subject.reblogged?(original_reblog)).to eq false
      end
    end

    context 'when the status is an original status' do
      it 'is true when this account has reblogged it' do
        Fabricate(:status, reblog: original_status, account: subject)

        expect(subject.reblogged?(original_status)).to eq true
      end

      it 'is false when this account has not reblogged it' do
        expect(subject.reblogged?(original_status)).to eq false
      end
    end
  end

  describe '#excluded_from_timeline_account_ids' do
    it 'includes account ids of blockings, blocked_bys and mutes' do
      account = Fabricate(:account)
      block = Fabricate(:block, account: account)
      mute = Fabricate(:mute, account: account)
      block_by = Fabricate(:block, target_account: account)

      results = account.excluded_from_timeline_account_ids
      expect(results.size).to eq 3
      expect(results).to include(block.target_account.id)
      expect(results).to include(mute.target_account.id)
      expect(results).to include(block_by.account.id)
    end
  end

  describe '#excluded_from_timeline_domains' do
    it 'returns the domains blocked by the account' do
      account = Fabricate(:account)
      account.block_domain!('domain')
      expect(account.excluded_from_timeline_domains).to match_array ['domain']
    end
  end

  describe '#statuses_count' do
    subject { Fabricate(:account) }

    it 'counts statuses' do
      Fabricate(:status, account: subject)
      Fabricate(:status, account: subject)
      expect(subject.statuses_count).to eq 2
    end

    it 'does not count direct statuses' do
      Fabricate(:status, account: subject, visibility: :direct)
      expect(subject.statuses_count).to eq 0
    end

    it 'is decremented when status is removed' do
      status = Fabricate(:status, account: subject)
      expect(subject.statuses_count).to eq 1
      status.destroy
      expect(subject.statuses_count).to eq 0
    end

    it 'is decremented when status is removed when account is not preloaded' do
      status = Fabricate(:status, account: subject)
      expect(subject.reload.statuses_count).to eq 1
      clean_status = Status.find(status.id)
      expect(clean_status.association(:account).loaded?).to be false
      clean_status.destroy
      expect(subject.reload.statuses_count).to eq 0
    end
  end

  describe '.following_map' do
    it 'returns an hash' do
      expect(Account.following_map([], 1)).to be_a Hash
    end
  end

  describe '.followed_by_map' do
    it 'returns an hash' do
      expect(Account.followed_by_map([], 1)).to be_a Hash
    end
  end

  describe '.blocking_map' do
    it 'returns an hash' do
      expect(Account.blocking_map([], 1)).to be_a Hash
    end
  end

  describe '.requested_map' do
    it 'returns an hash' do
      expect(Account.requested_map([], 1)).to be_a Hash
    end
  end

  describe 'MENTION_RE' do
    subject { Account::MENTION_RE }

    it 'matches usernames in the middle of a sentence' do
      expect(subject.match('Hello to @alice from me')[1]).to eq 'alice'
    end

    it 'matches usernames in the beginning of status' do
      expect(subject.match('@alice Hey how are you?')[1]).to eq 'alice'
    end

    it 'matches full usernames' do
      expect(subject.match('@alice@example.com')[1]).to eq 'alice@example.com'
    end

    it 'matches full usernames with a dot at the end' do
      expect(subject.match('Hello @alice@example.com.')[1]).to eq 'alice@example.com'
    end

    it 'matches dot-prepended usernames' do
      expect(subject.match('.@alice I want everybody to see this')[1]).to eq 'alice'
    end

    it 'does not match e-mails' do
      expect(subject.match('Drop me an e-mail at alice@example.com')).to be_nil
    end

    it 'does not match URLs' do
      expect(subject.match('Check this out https://medium.com/@alice/some-article#.abcdef123')).to be_nil
    end

    xit 'does not match URL querystring' do
      expect(subject.match('https://example.com/?x=@alice')).to be_nil
    end
  end

  describe 'validations' do
    it 'has a valid fabricator' do
      account = Fabricate.build(:account)
      account.valid?
      expect(account).to be_valid
    end

    it 'is invalid without a username' do
      account = Fabricate.build(:account, username: nil)
      account.valid?
      expect(account).to model_have_error_on_field(:username)
    end

    it 'squishes the username before validation' do
      account = Fabricate(:account, domain: nil, username: " \u3000bob \t \u00a0 \n ")
      expect(account.username).to eq 'bob'
    end

    context 'when is local' do
      it 'is invalid if the username is not unique in case-insensitive comparison among local accounts' do
        account_1 = Fabricate(:account, username: 'the_doctor')
        account_2 = Fabricate.build(:account, username: 'the_Doctor')
        account_2.valid?
        expect(account_2).to model_have_error_on_field(:username)
      end

      it 'is invalid if the username is reserved' do
        account = Fabricate.build(:account, username: 'support')
        account.valid?
        expect(account).to model_have_error_on_field(:username)
      end

      it 'is valid when username is reserved but record has already been created' do
        account = Fabricate.build(:account, username: 'support')
        account.save(validate: false)
        expect(account.valid?).to be true
      end

      it 'is valid if we are creating an instance actor account with a period' do
        account = Fabricate.build(:account, id: -99, actor_type: 'Application', locked: true, username: 'example.com')
        expect(account.valid?).to be true
      end

      it 'is valid if we are creating a possibly-conflicting instance actor account' do
        account_1 = Fabricate(:account, username: 'examplecom')
        account_2 = Fabricate.build(:account, id: -99, actor_type: 'Application', locked: true, username: 'example.com')
        expect(account_2.valid?).to be true
      end

      it 'is invalid if the username doesn\'t only contains letters, numbers and underscores' do
        account = Fabricate.build(:account, username: 'the-doctor')
        account.valid?
        expect(account).to model_have_error_on_field(:username)
      end

      it 'is invalid if the username contains a period' do
        account = Fabricate.build(:account, username: 'the.doctor')
        account.valid?
        expect(account).to model_have_error_on_field(:username)
      end

      it 'is invalid if the username is longer then 30 characters' do
        account = Fabricate.build(:account, username: Faker::Lorem.characters(number: 31))
        account.valid?
        expect(account).to model_have_error_on_field(:username)
      end

      it 'is invalid if the display name is longer than 30 characters' do
        account = Fabricate.build(:account, display_name: Faker::Lorem.characters(number: 31))
        account.valid?
        expect(account).to model_have_error_on_field(:display_name)
      end

      it 'is invalid if the note is longer than 500 characters' do
        account = Fabricate.build(:account, note: Faker::Lorem.characters(number: 501))
        account.valid?
        expect(account).to model_have_error_on_field(:note)
      end
    end

    context 'when is remote' do
      it 'is invalid if the username is same among accounts in the same normalized domain' do
        Fabricate(:account, domain: 'にゃん', username: 'username')
        account = Fabricate.build(:account, domain: 'xn--r9j5b5b', username: 'username')
        account.valid?
        expect(account).to model_have_error_on_field(:username)
      end

      it 'is invalid if the username is not unique in case-insensitive comparison among accounts in the same normalized domain' do
        Fabricate(:account, domain: 'にゃん', username: 'username')
        account = Fabricate.build(:account, domain: 'xn--r9j5b5b', username: 'Username')
        account.valid?
        expect(account).to model_have_error_on_field(:username)
      end

      it 'is valid even if the username contains hyphens' do
        account = Fabricate.build(:account, domain: 'domain', username: 'the-doctor')
        account.valid?
        expect(account).to_not model_have_error_on_field(:username)
      end

      it 'is invalid if the username doesn\'t only contains letters, numbers, underscores and hyphens' do
        account = Fabricate.build(:account, domain: 'domain', username: 'the doctor')
        account.valid?
        expect(account).to model_have_error_on_field(:username)
      end

      it 'is valid even if the username is longer then 30 characters' do
        account = Fabricate.build(:account, domain: 'domain', username: Faker::Lorem.characters(number: 31))
        account.valid?
        expect(account).not_to model_have_error_on_field(:username)
      end

      it 'is valid even if the display name is longer than 30 characters' do
        account = Fabricate.build(:account, domain: 'domain', display_name: Faker::Lorem.characters(number: 31))
        account.valid?
        expect(account).not_to model_have_error_on_field(:display_name)
      end

      it 'is valid even if the note is longer than 500 characters' do
        account = Fabricate.build(:account, domain: 'domain', note: Faker::Lorem.characters(number: 501))
        account.valid?
        expect(account).not_to model_have_error_on_field(:note)
      end
    end
  end

  describe 'scopes' do
    describe 'alphabetic' do
      it 'sorts by alphabetic order of domain and username' do
        matches = [
          { username: 'a', domain: 'a' },
          { username: 'b', domain: 'a' },
          { username: 'a', domain: 'b' },
          { username: 'b', domain: 'b' },
        ].map(&method(:Fabricate).curry(2).call(:account))

        expect(Account.where('id > 0').alphabetic).to eq matches
      end
    end

    describe 'matches_display_name' do
      it 'matches display name which starts with the given string' do
        match = Fabricate(:account, display_name: 'pattern and suffix')
        Fabricate(:account, display_name: 'prefix and pattern')

        expect(Account.matches_display_name('pattern')).to eq [match]
      end
    end

    describe 'matches_username' do
      it 'matches display name which starts with the given string' do
        match = Fabricate(:account, username: 'pattern_and_suffix')
        Fabricate(:account, username: 'prefix_and_pattern')

        expect(Account.matches_username('pattern')).to eq [match]
      end
    end

    describe 'by_domain_and_subdomains' do
      it 'returns exact domain matches' do
        account = Fabricate(:account, domain: 'example.com')
        expect(Account.by_domain_and_subdomains('example.com')).to eq [account]
      end

      it 'returns subdomains' do
        account = Fabricate(:account, domain: 'foo.example.com')
        expect(Account.by_domain_and_subdomains('example.com')).to eq [account]
      end

      it 'does not return partially matching domains' do
        account = Fabricate(:account, domain: 'grexample.com')
        expect(Account.by_domain_and_subdomains('example.com')).to_not eq [account]
      end
    end

    describe 'remote' do
      it 'returns an array of accounts who have a domain' do
        account_1 = Fabricate(:account, domain: nil)
        account_2 = Fabricate(:account, domain: 'example.com')
        expect(Account.remote).to match_array([account_2])
      end
    end

    describe 'local' do
      it 'returns an array of accounts who do not have a domain' do
        account_1 = Fabricate(:account, domain: nil)
        account_2 = Fabricate(:account, domain: 'example.com')
        expect(Account.where('id > 0').local).to match_array([account_1])
      end
    end

    describe 'partitioned' do
      it 'returns a relation of accounts partitioned by domain' do
        matches = ['a', 'b', 'a', 'b']
        matches.size.times.to_a.shuffle.each do |index|
          matches[index] = Fabricate(:account, domain: matches[index])
        end

        expect(Account.where('id > 0').partitioned).to match_array(matches)
      end
    end

    describe 'recent' do
      it 'returns a relation of accounts sorted by recent creation' do
        matches = 2.times.map { Fabricate(:account) }
        expect(Account.where('id > 0').recent).to match_array(matches)
      end
    end

    describe 'silenced' do
      it 'returns an array of accounts who are silenced' do
        account_1 = Fabricate(:account, silenced: true)
        account_2 = Fabricate(:account, silenced: false)
        expect(Account.silenced).to match_array([account_1])
      end
    end

    describe 'suspended' do
      it 'returns an array of accounts who are suspended' do
        account_1 = Fabricate(:account, suspended: true)
        account_2 = Fabricate(:account, suspended: false)
        expect(Account.suspended).to match_array([account_1])
      end
    end
  end

  context 'when is local' do
    # Test disabled because test environment omits autogenerating keys for performance
    xit 'generates keys' do
      account = Account.create!(domain: nil, username: Faker::Internet.user_name(separators: ['_']))
      expect(account.keypair.private?).to eq true
    end
  end

  context 'when is remote' do
    it 'does not generate keys' do
      key = OpenSSL::PKey::RSA.new(1024).public_key
      account = Account.create!(domain: 'remote', username: Faker::Internet.user_name(separators: ['_']), public_key: key.to_pem)
      expect(account.keypair.params).to eq key.params
    end

    it 'normalizes domain' do
      account = Account.create!(domain: 'にゃん', username: Faker::Internet.user_name(separators: ['_']))
      expect(account.domain).to eq 'xn--r9j5b5b'
    end
  end

  include_examples 'AccountAvatar', :account
  include_examples 'AccountHeader', :account

  describe '#increment_count!' do
    subject { Fabricate(:account) }

    it 'increments the count in multi-threaded an environment when account_stat is not yet initialized' do
      subject

      increment_by   = 15
      wait_for_start = true

      threads = Array.new(increment_by) do
        Thread.new do
          true while wait_for_start
          Account.find(subject.id).increment_count!(:followers_count)
        end
      end

      wait_for_start = false
      threads.each(&:join)

      expect(subject.reload.followers_count).to eq 15
    end
  end
end

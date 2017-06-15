# frozen_string_literal: true

require 'rails_helper'

describe StatusThreadingConcern do
  describe '#ancestors' do
    let!(:alice)  { Fabricate(:account, username: 'alice') }
    let!(:bob)    { Fabricate(:account, username: 'bob', domain: 'example.com') }
    let!(:jeff)   { Fabricate(:account, username: 'jeff') }
    let!(:status) { Fabricate(:status, account: alice) }
    let!(:reply1) { Fabricate(:status, thread: status, account: jeff) }
    let!(:reply2) { Fabricate(:status, thread: reply1, account: bob) }
    let!(:reply3) { Fabricate(:status, thread: reply2, account: alice) }
    let!(:viewer) { Fabricate(:account, username: 'viewer') }

    it 'returns conversation history' do
      expect(reply3.ancestors).to include(status, reply1, reply2)
    end

    it 'does not return conversation history user is not allowed to see' do
      reply1.update(visibility: :private)
      status.update(visibility: :direct)

      expect(reply3.ancestors(viewer)).to_not include(reply1, status)
    end

    it 'does not return conversation history from blocked users' do
      viewer.block!(jeff)
      expect(reply3.ancestors(viewer)).to_not include(reply1)
    end

    it 'does not return conversation history from muted users' do
      viewer.mute!(jeff)
      expect(reply3.ancestors(viewer)).to_not include(reply1)
    end

    it 'does not return conversation history from silenced and not followed users' do
      jeff.update(silenced: true)
      expect(reply3.ancestors(viewer)).to_not include(reply1)
    end

    it 'does not return conversation history from blocked domains' do
      viewer.block_domain!('example.com')
      expect(reply3.ancestors(viewer)).to_not include(reply2)
    end

    it 'ignores deleted records' do
      first_status  = Fabricate(:status, account: bob)
      second_status = Fabricate(:status, thread: first_status, account: alice)

      # Create cache and delete cached record
      second_status.ancestors
      first_status.destroy

      expect(second_status.ancestors).to eq([])
    end
  end

  describe '#descendants' do
    let!(:alice)  { Fabricate(:account, username: 'alice') }
    let!(:bob)    { Fabricate(:account, username: 'bob', domain: 'example.com') }
    let!(:jeff)   { Fabricate(:account, username: 'jeff') }
    let!(:status) { Fabricate(:status, account: alice) }
    let!(:reply1) { Fabricate(:status, thread: status, account: alice) }
    let!(:reply2) { Fabricate(:status, thread: status, account: bob) }
    let!(:reply3) { Fabricate(:status, thread: reply1, account: jeff) }
    let!(:viewer) { Fabricate(:account, username: 'viewer') }

    it 'returns replies' do
      expect(status.descendants).to include(reply1, reply2, reply3)
    end

    it 'does not return replies user is not allowed to see' do
      reply1.update(visibility: :private)
      reply3.update(visibility: :direct)

      expect(status.descendants(viewer)).to_not include(reply1, reply3)
    end

    it 'does not return replies from blocked users' do
      viewer.block!(jeff)
      expect(status.descendants(viewer)).to_not include(reply3)
    end

    it 'does not return replies from muted users' do
      viewer.mute!(jeff)
      expect(status.descendants(viewer)).to_not include(reply3)
    end

    it 'does not return replies from silenced and not followed users' do
      jeff.update(silenced: true)
      expect(status.descendants(viewer)).to_not include(reply3)
    end

    it 'does not return replies from blocked domains' do
      viewer.block_domain!('example.com')
      expect(status.descendants(viewer)).to_not include(reply2)
    end
  end
end

require 'rails_helper'

describe AccountStatusesCleanupService, type: :service do
  let(:account)           { Fabricate(:account, username: 'alice', domain: nil) }
  let(:account_policy)    { Fabricate(:account_statuses_cleanup_policy, account: account) }
  let!(:unrelated_status) { Fabricate(:status, created_at: 3.years.ago) }

  describe '#call' do
    context 'when the account has not posted anything' do
      it 'returns 0 deleted toots' do
        expect(subject.call(account_policy)).to eq 0
      end
    end

    context 'when the account has posted several old statuses' do
      let!(:very_old_status)    { Fabricate(:status, created_at: 3.years.ago, account: account) }
      let!(:old_status)         { Fabricate(:status, created_at: 1.year.ago, account: account) }
      let!(:another_old_status) { Fabricate(:status, created_at: 1.year.ago, account: account) }

      context 'given a budget of 1' do
        it 'reports 1 deleted toot' do
          expect(subject.call(account_policy, 1)).to eq 1
        end
      end

      context 'given a normal budget of 10' do
        it 'reports 3 deleted statuses' do
          expect(subject.call(account_policy, 10)).to eq 3
        end

        it 'records the last deleted id' do
          subject.call(account_policy, 10)
          expect(account_policy.last_inspected).to eq [old_status.id, another_old_status.id].max
        end

        #TODO: it actually deletes statuses
      end

      context 'when called repeatedly with a budget of 2' do
        it 'reports 2 then 1 deleted statuses' do
         expect(subject.call(account_policy, 2)).to eq 2
         expect(subject.call(account_policy, 2)).to eq 1
        end

        #TODO: it actually deletes statuses
      end

      context 'when there are more un-deletable old toots than the early search cutoff' do
        before do
          stub_const 'AccountStatusesCleanupPolicy::EARLY_SEARCH_CUTOFF', 5
          for _ in (1..10)
            Fabricate(:status, created_at: 4.years.ago, visibility: :direct, account: account)
          end
        end

        it 'reports 0 deleted statuses then 0 then 3' do
          expect(subject.call(account_policy, 10)).to eq 0
          expect(subject.call(account_policy, 10)).to eq 0
          expect(subject.call(account_policy, 10)).to eq 3
        end
      end
    end
  end
end

# frozen_string_literal: true

class AccountStatusesCleanupService < BaseService
  # @param [AccountStatusesCleanupPolicy] account_policy
  # @param [Integer] budget
  # @return [Integer]
  def call(account_policy, budget = 50)
    return 0 unless account_policy.enabled?

    cutoff_id = account_policy.compute_cutoff_id
    return 0 if cutoff_id.blank?

    nb_deleted = 0
    last_deleted = nil

    account_policy.statuses_to_delete(budget, cutoff_id, account_policy.last_inspected).reorder(nil).find_each(order: :asc) do |status|
      status.discard
      RemovalWorker.perform_async(status.id, redraft: false)
      nb_deleted += 1
      last_deleted = status.id
    end

    account_policy.record_last_inspected(last_deleted.presence || cutoff_id)

    nb_deleted
  end
end

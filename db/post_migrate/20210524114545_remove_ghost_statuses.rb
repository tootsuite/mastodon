class RemoveGhostStatuses < ActiveRecord::Migration[6.1]
  def change
    Status.where(uri: Tombstone.select(:uri)).delete_all
  end
end

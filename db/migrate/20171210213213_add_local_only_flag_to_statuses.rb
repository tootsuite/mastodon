class AddLocalOnlyFlagToStatuses < ActiveRecord::Migration[5.1]
  def change
    add_column :statuses, :local_only, :boolean
  end
end

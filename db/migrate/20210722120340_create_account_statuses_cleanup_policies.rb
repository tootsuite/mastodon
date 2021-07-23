class CreateAccountStatusesCleanupPolicies < ActiveRecord::Migration[6.1]
  def change
    create_table :account_statuses_cleanup_policies do |t|
      t.belongs_to :account, null: false, foreign_key: { on_delete: :cascade }
      t.boolean :enabled, null: false, default: true
      t.integer :min_status_age, null: false, default: 2.weeks.seconds
      t.boolean :keep_direct, null: false, default: true
      t.boolean :keep_pinned, null: false, default: true
      t.boolean :keep_polls, null: false, default: false
      t.boolean :keep_media, null: false, default: false
      t.boolean :keep_self_fav, null: false, default: true
      t.boolean :keep_self_bookmark, null: false, default: true

      t.timestamps
    end
  end
end


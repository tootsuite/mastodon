class CreateRegistrationFilters < ActiveRecord::Migration[6.1]
  def change
    create_table :registration_filters do |t|
      t.text :phrase, null: false, default: ''
      t.integer :type, null: false, default: 0
      t.boolean :whole_word, null: false, default: true

      t.timestamps
    end
  end
end

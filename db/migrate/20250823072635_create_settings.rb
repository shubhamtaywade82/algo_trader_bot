class CreateSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :settings do |t|
      t.string :key,   null: false
      t.text   :value, null: true

      t.timestamps
    end
    add_index :settings, :key, unique: true
  end
end

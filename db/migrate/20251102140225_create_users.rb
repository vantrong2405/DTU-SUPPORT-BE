class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.text :email, null: false
      t.text :name
      t.jsonb :tokens
      t.references :subscription_plan, null: true, foreign_key: true

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end

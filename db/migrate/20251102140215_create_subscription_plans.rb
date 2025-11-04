# frozen_string_literal: true

class CreateSubscriptionPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :subscription_plans do |t|
      t.text :name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :duration_days, null: false
      t.jsonb :features
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :subscription_plans, :name
    add_index :subscription_plans, :is_active
  end
end

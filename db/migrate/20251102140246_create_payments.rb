class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :subscription_plan, null: false, foreign_key: true, index: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.text :payment_method, null: false
      t.text :status, null: false
      t.jsonb :transaction_data
      t.timestamptz :expired_at

      t.timestamps
    end

    add_index :payments, :user_id
    add_index :payments, :subscription_plan_id
    add_index :payments, :status
    add_index :payments, :created_at, order: { created_at: :desc }
  end
end

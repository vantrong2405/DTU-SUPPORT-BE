class CreateAiScheduleResult < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_schedule_results do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.jsonb :input_data, null: false
      t.jsonb :ai_result
      t.text :model_name
      t.string :status, limit: 20, null: false

      t.timestamps
    end

    add_index :ai_schedule_results, :user_id
    add_index :ai_schedule_results, :status
    add_index :ai_schedule_results, :created_at, order: { created_at: :desc }
  end
end

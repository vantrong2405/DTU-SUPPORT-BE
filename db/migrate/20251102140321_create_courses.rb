class CreateCourses < ActiveRecord::Migration[8.0]
  def change
    create_table :courses do |t|
      t.text :course_code, null: false
      t.text :course_name, null: false
      t.integer :credits, null: false
      t.jsonb :schedule
      t.text :lecturer
      t.text :semester, null: false
      t.references :crawl_course_config, null: true, foreign_key: true

      t.timestamps
    end

    add_index :courses, :course_code
    add_index :courses, :crawl_course_config_id, name: "idx_courses_config_id"
    add_index :courses, :semester
  end
end

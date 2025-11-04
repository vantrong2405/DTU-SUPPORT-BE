# frozen_string_literal: true

class CreateCrawlCourseConfig < ActiveRecord::Migration[8.0]
  def change
    create_table :crawl_course_configs do |t|
      t.text :config_name, null: false
      t.text :url, null: false
      t.references :user, null: false, foreign_key: true
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :crawl_course_configs, :user_id, name: "idx_crawl_course_config_created_by"
    add_index :crawl_course_configs, :is_active
  end
end

# frozen_string_literal: true

class CreateCrawlCourseJob < ActiveRecord::Migration[8.0]
  def change
    create_table :crawl_course_jobs do |t|
      t.references :crawl_course_config, null: false, foreign_key: true
      t.string :status, limit: 20, null: false
      t.jsonb :run_result
      t.timestamptz :started_at, default: -> { "now()" }
      t.timestamptz :finished_at

      t.timestamps
    end

    add_index :crawl_course_jobs, :crawl_course_config_id, name: "idx_crawl_course_job_config_id"
    add_index :crawl_course_jobs, :status
    add_index :crawl_course_jobs, :started_at, order: { started_at: :desc }
  end
end

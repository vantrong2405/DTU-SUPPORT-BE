namespace :db do
  desc "Create database if not exists"
  task create_custom: :environment do
    db_config = ActiveRecord::Base.connection_db_config
    db_name = db_config.database
    master_config = db_config.configuration_hash.merge(database: "postgres")

    ActiveRecord::Base.establish_connection(master_config)
    connection = ActiveRecord::Base.connection

    result = connection.execute("SELECT 1 FROM pg_database WHERE datname = '#{connection.quote_string(db_name)}'")

    if result.values.empty?
      connection.execute("CREATE DATABASE #{connection.quote_table_name(db_name)}")
      puts "SUCCESS: Database #{db_name} created"
    else
      puts "SUCCESS: Database #{db_name} already exists"
    end

    ActiveRecord::Base.establish_connection(Rails.env.to_sym)
  end

  desc "Run custom SQL migration"
  task migrate_custom: :environment do
    migration_file = Rails.root.join("db", "migrate", "20250101000000_create_course_registration_schema.sql")

    unless migration_file.exist?
      puts "FAIL: Migration file not found: #{migration_file}"
      exit 1
    end

    sql_content = migration_file.read
    ActiveRecord::Base.connection.execute(sql_content)
    puts "SUCCESS: Migration completed"
  rescue ActiveRecord::StatementInvalid => e
    if e.message.include?("already exists")
      puts "SUCCESS: Tables already exist, migration skipped"
    else
      puts "FAIL: #{e.message}"
      exit 1
    end
  end

  desc "Test database connection"
  task test_connection: :environment do
    result = ActiveRecord::Base.connection.execute("SELECT 1 AS test")
    if result.first && result.first["test"] == 1
      puts "SUCCESS"
      exit 0
    else
      puts "FAIL"
      exit 1
    end
  rescue => e
    puts "FAIL: #{e.message}"
    exit 1
  end
end

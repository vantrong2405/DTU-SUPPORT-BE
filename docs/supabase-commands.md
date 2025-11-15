# Supabase Commands - DTU Support BE

Lệnh tương tác với Supabase database.

## Vấn Đề

Rails đang migrate vào database `dtu_support`, nhưng **Supabase Dashboard chỉ hiển thị tables từ database `postgres` (default)**.

## Giải Pháp

### Bước 1: Đổi Database trong .env

Sửa file `.env`:

```bash
# Thay đổi từ:
SUPABASE_DB_NAME=dtu_support

# Thành:
SUPABASE_DB_NAME=postgres
```

### Bước 2: Drop Tables cũ trong Postgres

```bash
bin/rails runner "ActiveRecord::Base.connection.execute(\"DROP TABLE IF EXISTS courses, crawl_course_jobs, crawl_course_configs, ai_schedule_results, users, subscription_plans CASCADE;\")"
```

### Bước 3: Migrate lại vào Postgres

```bash
bin/rails db:migrate
```

Sau khi chạy xong, tables sẽ hiển thị trên Supabase Dashboard.

## Lệnh Thường Dùng

### Drop Database và Migrate lại

```bash
bin/rails db:drop
bin/rails db:migrate
```

### Test Connection

```bash
bin/rails runner "puts ActiveRecord::Base.connection.current_database"
```

### List Tables

```bash
bin/rails runner "puts ActiveRecord::Base.connection.tables.sort"
```

## Environment Variables

File `.env` cần có:

```bash
SUPABASE_DB_HOST=db.xxxxx.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_USERNAME=postgres
SUPABASE_DB_PASSWORD=your_password
SUPABASE_DB_NAME=postgres
```

**Lưu ý:** `SUPABASE_DB_NAME=postgres` để tables hiển thị trên Supabase Dashboard.

# Database Migration Guide

## Quick Commands

### Create Database (if not exists)
```bash
rails db:create_custom
```

### Generate Migration
```bash
rails generate migration CreateTableName field:type
```

### Run Migration
```bash
rails db:migrate
```

### Test Database Connection
```bash
rails db:test_connection
```

### Full Setup (All-in-one)
```bash
rails db:create_custom && rails db:migrate && rails db:test_connection
```

## Manual Migration (Alternative)

### Using psql
```bash
psql -h $SUPABASE_DB_HOST \
     -p $SUPABASE_DB_PORT \
     -U $SUPABASE_DB_USERNAME \
     -d $SUPABASE_DB_NAME \
     -f db/migrate/20250101000000_create_course_registration_schema.sql
```

### Using Supabase CLI
```bash
supabase db push
```

### Using Rails Console
```ruby
sql = File.read("db/migrate/20250101000000_create_course_registration_schema.sql")
ActiveRecord::Base.connection.execute(sql)
```

## Environment Variables Required

Make sure these variables are set in `.env`:

```bash
SUPABASE_DB_HOST=db.xxxxx.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_USERNAME=postgres
SUPABASE_DB_PASSWORD=your-password
SUPABASE_DB_NAME=dtu_support
```

**Important**: You need to get `SUPABASE_DB_PASSWORD` from Supabase Dashboard:
1. Go to Project Settings → Database
2. Find "Connection string" or "Database password"
3. Copy the password and set it in `.env` file

If password is missing, migration and test will fail with connection error.

## Migration Files

Migration files are located in `db/migrate/`:

- `20250101000000_create_course_registration_schema.sql` - Creates all tables, indexes, and constraints

## Tables Created

1. `subscription_plans` - Subscription plans (Free, Pro, Premium)
2. `users` - User accounts with authentication
3. `crawl_course_config` - Crawl configuration
4. `payments` - Payment history
5. `ai_schedule_result` - AI schedule results
6. `crawl_course_job` - Crawl job tracking
7. `courses` - Course information

## Verification

After migration, verify tables exist:

```bash
psql -h $SUPABASE_DB_HOST \
     -p $SUPABASE_DB_PORT \
     -U $SUPABASE_DB_USERNAME \
     -d $SUPABASE_DB_NAME \
     -c "\dt"
```

Or using Rails console:

```ruby
ActiveRecord::Base.connection.tables.sort
```

# 🧭 Hệ thống Đăng ký Tín chỉ & Gợi ý Lịch học Tự động

## 🎯 Mục tiêu

Xây dựng hệ thống đăng ký tín chỉ thông minh:
- Crawl dữ liệu môn học/lớp học từ website trường → Lưu vào Supabase
- AI đề xuất lịch học phù hợp dựa trên thông tin cá nhân (nơi ở, giờ rảnh, giờ làm)
- Tự động cập nhật khi trường thay đổi thông tin
- Lưu log để check matching (debug/tracking, không hiển thị ra UI)

**URL cần crawl:**
```
https://courses.duytan.edu.vn/Sites/Home_ChuongTrinhDaoTao.aspx?p=home_listcoursedetail&courseid=57&timespan=91&t=s
```

---

## 🏗️ 1. Cấu trúc Database

## 🔗 Sơ đồ tổng quan các bảng

```
┌──────────────────────────────────────────────┐
│                    users                       │
├──────────────────────────────────────────────┤
│ 🔑 id (PK, uuid)                              │
│ 🔑 email (UK, text)                           │
│    name (text)                                │
│    tokens (jsonb)                             │
│ 🔗 plan_id (FK → subscription_plans.id)      │
│    created_at (timestamptz)                  │
│    updated_at (timestamptz)                  │
└──────────────────────────────────────────────┘
         │                    │                   │
         │ N:1                │ 1:N               │ 1:N
         │                    │                   │
         ▼                    ▼                   ▼
┌──────────────────────┐  ┌─────────────────┐  ┌───────────────────────────────┐
│  subscription_plans   │  │    payments      │  │  crawl_course_config          │
├──────────────────────┤  ├─────────────────┤  ├───────────────────────────────┤
│ 🔑 id (PK,           │  │ 🔑 id (PK,       │  │ 🔑 id (PK, bigserial)         │
│    bigserial)         │  │    bigserial)     │  │    config_name (text)         │
│    name (text)        │  │ 🔗 user_id (FK → │  │    url (text)                  │
│    price (numeric)    │  │    users.id)      │  │ 🔗 created_by (FK →           │
│    duration_days (int)│  │ 🔗 plan_id (FK →  │  │    users.id)                  │
│    features (jsonb)   │  │    plans.id)       │  │    is_active (boolean)         │
│    is_active (boolean)│  │    amount         │  │    created_at (timestamptz)    │
└──────────────────────┘  │      (numeric)     │  │    updated_at (timestamptz)    │
                          │    payment_method  │  └───────────────────────────────┘
                          │      (text)        │              │
                          │    status (text)   │              │ 1:N
                          │    transaction_    │              │
                          │    data (jsonb)    │              ▼
                          │    created_at      │  ┌───────────────────────────────┐
                          │    expired_at      │  │   crawl_course_job            │
                          │      (timestamptz)  │  ├───────────────────────────────┤
                          └─────────────────┘  │ 🔑 id (PK, bigserial)           │
                                               │ 🔗 crawl_course_config_id (FK)   │
┌──────────────────────────────────────────────┐│    status (varchar)              │
│        ai_schedule_result                     ││    run_result (jsonb)           │
├──────────────────────────────────────────────┤│    started_at (timestamptz)      │
│ 🔑 id (PK, bigserial)                        ││    finished_at (timestamptz)    │
│ 🔗 user_id (FK → users.id)                   │└───────────────────────────────┘
│    input_data (jsonb)                        │              │
│    ai_result (jsonb)                         │              │ 1:N
│    model_name (text)                         │              │
│    status (varchar)                          │              ▼
│    created_at (timestamptz)                   │  ┌───────────────────────────────┐
└──────────────────────────────────────────────┘│          courses                │
                                                 ├───────────────────────────────┤
                                                 │ 🔑 id (PK, bigserial)          │
                                                 │    course_code (text)          │
                                                 │    course_name (text)          │
                                                 │    credits (int)               │
                                                 │    schedule (jsonb)            │
                                                 │    lecturer (text)             │
                                                 │    semester (text)             │
                                                 │ 🔗 crawl_course_config_id (FK) │
                                                 │    created_at (timestamptz)    │
                                                 │    updated_at (timestamptz)    │
                                                 └───────────────────────────────┘
```

**Mối quan hệ:**
- `users` → `subscription_plans` (N:1) - FK: `users.plan_id` → `subscription_plans.id`
- `users` → `payments` (1:N) - FK: `payments.user_id` → `users.id`
- `subscription_plans` → `payments` (1:N) - FK: `payments.plan_id` → `subscription_plans.id`
- `users` → `crawl_course_config` (1:N) - FK: `crawl_course_config.created_by` → `users.id`
- `users` → `ai_schedule_result` (1:N) - FK: `ai_schedule_result.user_id` → `users.id`
- `crawl_course_config` → `crawl_course_job` (1:N) - FK: `crawl_course_job.crawl_course_config_id` → `crawl_course_config.id`
- `crawl_course_config` → `courses` (1:N) - FK: `courses.crawl_course_config_id` → `crawl_course_config.id`

---

## 📋 Chi tiết từng bảng

### 🔹 Bảng `users`

**Mục đích:** Lưu thông tin người dùng và authentication

| Cột | Kiểu dữ liệu | Constraints | Mô tả |
|------|--------------|-------------|-------|
| `id` | uuid | PRIMARY KEY, DEFAULT gen_random_uuid() | ID user |
| `email` | text | UNIQUE, NOT NULL | Email Google |
| `name` | text | | Tên người dùng |
| `tokens` | jsonb | | `{ "access_token": "...", "refresh_token": "..." }` |
| `plan_id` | bigint | FOREIGN KEY (subscription_plans.id) | Gói hiện tại |
| `created_at` | timestamptz | DEFAULT now() | Ngày tạo |
| `updated_at` | timestamptz | DEFAULT now() | Ngày cập nhật |

**Indexes:**
- `idx_users_email` trên `email` (UNIQUE index tự động)
- `idx_users_plan_id` trên `plan_id`

**Mối quan hệ:**
- `users` → `subscription_plans` (N:1) - FK: `users.plan_id` → `subscription_plans.id`
- `users` → `payments` (1:N) - FK: `payments.user_id` → `users.id`
- `users` → `crawl_course_config` (1:N) - FK: `crawl_course_config.created_by` → `users.id`
- `users` → `ai_schedule_result` (1:N) - FK: `ai_schedule_result.user_id` → `users.id`

**Ghi chú:**
- Lưu thông tin người dùng và tokens OAuth
- Liên kết với gói subscription hiện tại qua `plan_id`

---

### 🔹 Bảng `subscription_plans`

**Mục đích:** Quản lý các gói subscription (Free, Pro, Premium)

| Cột | Kiểu dữ liệu | Constraints | Mô tả |
|------|--------------|-------------|-------|
| `id` | bigserial | PRIMARY KEY | ID gói |
| `name` | text | NOT NULL | Tên gói (Free, Pro, Premium) |
| `price` | numeric(10,2) | NOT NULL | Giá theo tháng |
| `duration_days` | int | NOT NULL | Thời hạn (VD: 30 ngày) |
| `features` | jsonb | | `{ "ai_limit": 100, "crawl_limit": 50 }` |
| `is_active` | boolean | DEFAULT true | Bật/tắt gói |

**Indexes:**
- `idx_subscription_plans_name` trên `name`
- `idx_subscription_plans_is_active` trên `is_active`

**Mối quan hệ:**
- `subscription_plans` → `users` (1:N) - FK: `users.plan_id` → `subscription_plans.id`
- `subscription_plans` → `payments` (1:N) - FK: `payments.plan_id` → `subscription_plans.id`

**Ghi chú:**
- Quản lý các gói subscription với features và giá cả
- `features` là JSONB chứa các giới hạn (VD: `ai_limit`, `crawl_limit`)

---

### 🔹 Bảng `payments`

**Mục đích:** Lưu lịch sử thanh toán và subscription

| Cột | Kiểu dữ liệu | Constraints | Mô tả |
|------|--------------|-------------|-------|
| `id` | bigserial | PRIMARY KEY | ID payment (dùng làm `order_invoice_number` cho SenPay) |
| `user_id` | bigint | FOREIGN KEY (users.id), NOT NULL | ID user |
| `subscription_plan_id` | bigint | FOREIGN KEY (subscription_plans.id), NOT NULL | ID gói |
| `amount` | decimal(10,2) | NOT NULL | Số tiền thanh toán |
| `payment_method` | text | NOT NULL | Phương thức (senpay, paypal, stripe) |
| `status` | text | NOT NULL | Trạng thái (pending, success, failed, expired, cancelled) |
| `transaction_data` | jsonb | | Thông tin giao dịch chi tiết từ payment gateway |
| `expired_at` | timestamptz | | Hạn dùng đến (payment timeout) |
| `created_at` | datetime | DEFAULT now() | Ngày tạo |
| `updated_at` | datetime | DEFAULT now() | Ngày cập nhật |

**Indexes:**
- `index_payments_on_user_id` trên `user_id` (foreign key index)
- `index_payments_on_subscription_plan_id` trên `subscription_plan_id` (foreign key index)
- `index_payments_on_status` trên `status` (query by status)
- `index_payments_on_created_at` trên `created_at` DESC (order by created_at)

**Mối quan hệ:**
- `users` → `payments` (1:N) - FK: `payments.user_id` → `users.id`
- `subscription_plans` → `payments` (1:N) - FK: `payments.subscription_plan_id` → `subscription_plans.id`

**Ghi chú:**
- Lưu lịch sử thanh toán và thời hạn sử dụng
- `transaction_data` (JSONB) chứa thông tin chi tiết từ payment gateway

**Cấu trúc `transaction_data` cho SenPay:**

**1. Khi tạo payment (Payment Creation):**
```json
{
  "form_data": {
    "merchant": "YOUR_MERCHANT_ID",
    "order_amount": 100000,
    "order_invoice_number": "123",
    "order_description": "Subscription: Pro Plan",
    "return_url": "https://your-domain.com/payment/return",
    "ipn_url": "https://your-domain.com/api/webhooks/senpay",
    "signature": "GENERATED_SIGNATURE"
  },
  "checkout_url": "https://pay-sandbox.sepay.vn/v1/checkout/init"
}
```

**2. Khi nhận webhook (Webhook Callback):**
```json
{
  "notification_type": "ORDER_PAID",
  "order": {
    "order_invoice_number": "123",
    "order_amount": 100000,
    "order_status": "CAPTURED"
  },
  "transaction": {
    "id": "transaction_id_123",
    "gateway": "Vietcombank",
    "transaction_date": "2025-11-07T10:00:00Z",
    "amount_in": 100000,
    "amount_out": 0,
    "accumulated": 1000000,
    "code": "ORDER123",
    "reference_number": "REF123",
    "transaction_content": "Thanh toan don hang ORDER123",
    "account_number": "1234567890",
    "sub_account": null
  },
  "form_data": {
    "merchant": "YOUR_MERCHANT_ID",
    "order_amount": 100000,
    "order_invoice_number": "123",
    "signature": "GENERATED_SIGNATURE"
  },
  "checkout_url": "https://pay-sandbox.sepay.vn/v1/checkout/init"
}
```

**Các fields quan trọng cho idempotency check:**
- `transaction.id` - ID giao dịch trên SenPay (dùng để check duplicate)
- `transaction.code` - Mã thanh toán (nếu SenPay nhận diện được)
- `transaction.reference_number` - Mã tham chiếu
- `order.order_invoice_number` - Mã đơn hàng (tương ứng với `payment.id`)

**Idempotency check:**
- Query bằng JSONB operators: `WHERE transaction_data->'transaction'->>'id' = ?`
- Hoặc: `WHERE transaction_data->'order'->>'order_invoice_number' = ?`
- Có thể thêm indexes sau nếu cần performance

---

### 🔹 Bảng `crawl_course_config`

**Mục đích:** Quản lý cấu hình crawl nguồn dữ liệu môn học

| Cột | Kiểu dữ liệu | Constraints | Mô tả |
|------|--------------|-------------|-------|
| `id` | bigserial | PRIMARY KEY | ID config |
| `config_name` | text | NOT NULL | Tên config (VD: Crawl khóa CNTT HK1) |
| `url` | text | NOT NULL | URL nguồn dữ liệu |
| `created_by` | uuid | FOREIGN KEY (users.id), NOT NULL | Người tạo |
| `is_active` | boolean | DEFAULT true | Bật/tắt nguồn |
| `created_at` | timestamptz | DEFAULT now() | Ngày tạo |
| `updated_at` | timestamptz | DEFAULT now() | Ngày cập nhật |

**Indexes:**
- `idx_crawl_course_config_created_by` trên `created_by`
- `idx_crawl_course_config_is_active` trên `is_active`

**Mối quan hệ:**
- `users` → `crawl_course_config` (N:1) - FK: `crawl_course_config.created_by` → `users.id`
- `crawl_course_config` → `crawl_course_job` (1:N) - FK: `crawl_course_job.crawl_course_config_id` → `crawl_course_config.id`
- `crawl_course_config` → `courses` (1:N) - FK: `courses.crawl_course_config_id` → `crawl_course_config.id`

**Ghi chú:**
- Admin tạo config để crawl từ URL nguồn dữ liệu
- Có thể bật/tắt nguồn crawl qua `is_active`

---

### 🔹 Bảng `crawl_course_job`

**Mục đích:** Theo dõi từng lần chạy crawl job

| Cột | Kiểu dữ liệu | Constraints | Mô tả |
|------|--------------|-------------|-------|
| `id` | bigserial | PRIMARY KEY | ID job |
| `crawl_course_config_id` | bigint | FOREIGN KEY (crawl_course_config.id), NOT NULL | ID config |
| `status` | varchar(20) | NOT NULL | Trạng thái (pending / running / completed / failed) |
| `run_result` | jsonb | | `{ "fetched": 100, "inserted": 50, "updated": 30, "error": null }` |
| `started_at` | timestamptz | DEFAULT now() | Thời gian bắt đầu |
| `finished_at` | timestamptz | | Thời gian kết thúc |

**Indexes:**
- `idx_crawl_course_job_config_id` trên `crawl_course_config_id`
- `idx_crawl_course_job_status` trên `status`
- `idx_crawl_course_job_started_at` trên `started_at` DESC

**Mối quan hệ:**
- `crawl_course_config` → `crawl_course_job` (N:1) - FK: `crawl_course_job.crawl_course_config_id` → `crawl_course_config.id`

**Ghi chú:**
- Theo dõi từng lần crawl job chạy
- `run_result` chứa kết quả crawl (số lượng fetched, inserted, updated, lỗi nếu có)

---

### 🔹 Bảng `courses`

**Mục đích:** Lưu thông tin môn học đã crawl

| Cột | Kiểu dữ liệu | Constraints | Mô tả |
|------|--------------|-------------|-------|
| `id` | bigserial | PRIMARY KEY | ID môn học |
| `course_code` | text | NOT NULL | Mã môn học |
| `course_name` | text | NOT NULL | Tên môn học |
| `credits` | int | NOT NULL | Số tín chỉ |
| `schedule` | jsonb | | `{ "days": ["Tue","Fri"], "time": "07:00-09:00" }` |
| `lecturer` | text | | Tên giảng viên |
| `semester` | text | NOT NULL | Học kỳ |
| `crawl_course_config_id` | bigint | FOREIGN KEY (crawl_course_config.id) | ID config crawl |
| `created_at` | timestamptz | DEFAULT now() | Ngày tạo |
| `updated_at` | timestamptz | DEFAULT now() | Ngày cập nhật |

**Indexes:**
- `idx_courses_course_code` trên `course_code`
- `idx_courses_config_id` trên `crawl_course_config_id`
- `idx_courses_semester` trên `semester`

**Mối quan hệ:**
- `crawl_course_config` → `courses` (N:1) - FK: `courses.crawl_course_config_id` → `crawl_course_config.id`

**Ghi chú:**
- Lưu thông tin môn học đã crawl từ nguồn dữ liệu
- `schedule` là JSONB chứa lịch học (ngày, giờ)

---

### 🔹 Bảng `ai_schedule_result`

**Mục đích:** Lưu kết quả lập lịch học từ AI

| Cột | Kiểu dữ liệu | Constraints | Mô tả |
|------|--------------|-------------|-------|
| `id` | bigserial | PRIMARY KEY | ID result |
| `user_id` | uuid | FOREIGN KEY (users.id), NOT NULL | ID user |
| `input_data` | jsonb | NOT NULL | Dữ liệu gửi AI (mã môn, campus, giờ rảnh, v.v.) |
| `ai_result` | jsonb | | Kết quả AI (danh sách lớp được đề xuất) |
| `model_name` | text | | Model AI sử dụng (gemini-1.5, claude-3, v.v.) |
| `status` | varchar(20) | NOT NULL | Trạng thái (success / error) |
| `created_at` | timestamptz | DEFAULT now() | Ngày tạo |

**Indexes:**
- `idx_ai_schedule_result_user_id` trên `user_id`
- `idx_ai_schedule_result_status` trên `status`
- `idx_ai_schedule_result_created_at` trên `created_at` DESC

**Mối quan hệ:**
- `users` → `ai_schedule_result` (N:1) - FK: `ai_schedule_result.user_id` → `users.id`

**Ghi chú:**
- Lưu kết quả lập lịch học từ AI
- `input_data` chứa dữ liệu đầu vào (mã môn, campus, giờ rảnh, giờ làm)
- `ai_result` chứa kết quả AI (danh sách lớp được đề xuất)

---

## 🕸️ 2. Luồng hoạt động

### 2.1. Quy trình crawl dữ liệu

```
Admin nhập URL
    ↓
Lưu vào crawl_tasks (status: pending)
    ↓
Crawler bắt đầu crawl
    ↓
1. Crawl danh sách môn học
   - Parse HTML: code, name, detail_url
   - Upsert vào courses
    ↓
2. Crawl từng lớp học
   - Parse HTML: register_code, semester, credits, credit_type, days, dates, lecturer, slots, status, campus
   - So sánh với class_sections hiện tại
    ↓
3. Ghi log thay đổi
   - Nếu có thay đổi → tạo crawl_logs
   - Upsert vào class_sections
    ↓
4. Cập nhật crawl_tasks (status: done)
```

### 2.2. Quy trình lập lịch học với AI

```
Sinh viên nhập: mã môn, campus, giờ rảnh, giờ làm
    ↓
Query class_sections từ Supabase (filter: status='Còn hạn', available_slots>0)
    ↓
Gửi dữ liệu + prompt đến Google AI Studio
    ↓
AI phân tích và đề xuất lịch học phù hợp
    ↓
Hiển thị gợi ý thời khóa biểu
```

---

## 🧱 3. Các bước Crawler chi tiết

### Task 3.1: Nhập URL gốc

**Input:** URL (text)

**Output:** Record trong `crawl_tasks`

**Logic:**
1. Admin nhập URL danh sách môn học
2. Lưu vào `crawl_tasks` với `status = 'pending'`

**URL mẫu:**
```
https://courses.duytan.edu.vn/Sites/Home_ChuongTrinhDaoTao.aspx?p=home_listcoursedetail&courseid=57&timespan=91&t=s
```

---

### Task 3.2: Crawl danh sách môn học

**Input:** `crawl_task_id`

**Output:**
- Danh sách records trong `courses`
- Danh sách `detail_urls` để crawl lớp học

**Logic:**
1. Truy cập `base_url` từ `crawl_tasks`
2. Parse HTML và trích xuất:
   - Mã môn học (`code`)
   - Tên môn học (`name`)
   - Link chi tiết từng lớp (`detail_url`)
3. Upsert vào `courses` (onConflict: `code`)
4. Trả về danh sách `detail_urls`

**Lưu ý:**
- Trang có thể có pagination → cần crawl tất cả trang
- Link chi tiết có thể là relative path → cần convert sang absolute URL
- Một môn học có thể có nhiều lớp → crawl tất cả các lớp

---

### Task 3.3: Crawl từng lớp học chi tiết

**Input:**
- `detail_urls`
- `crawl_task_id`
- `crawl_run_id` (UUID mới)

**Output:**
- Danh sách records trong `class_sections`
- Danh sách records trong `crawl_logs` (nếu có thay đổi)

**Logic:**
1. Với mỗi `detail_url`:
   - Truy cập URL
   - Parse HTML và trích xuất:
     - `register_code`, `semester`, `credits`, `credit_type`
     - `days` (JSON array), `date_start`, `date_end`
     - `lecturer`, `total_slots`, `registered_slots`, `status`, `campus`
2. Kiểm tra `class_sections` có `register_code` hoặc `detail_url` chưa
3. So sánh với data cũ:
   - Nếu record mới → INSERT và log `change_type = 'created'`
   - Nếu record tồn tại và có thay đổi:
     - UPDATE record
     - Tạo `crawl_logs` với `change_type = 'updated'`, `old_data`, `new_data`, `change_summary`

**URL mẫu trang chi tiết:**
```
https://courses.duytan.edu.vn/Sites/Home_ChuongTrinhDaoTao.aspx?p=home_detailcourse&code=MTH293202501001
```

---

### Task 3.4: Ghi log thay đổi

**Input:**
- Danh sách thay đổi từ Task 3.3
- `crawl_run_id`

**Output:** Records trong `crawl_logs`

**Logic:**
1. Với mỗi thay đổi:
   - Tạo `crawl_logs` với:
     - `change_type`: created / updated / deleted
     - `field_changed`: Array field bị thay đổi
     - `old_data`, `new_data`: JSON snapshot
     - `change_summary`: Tóm tắt thay đổi

---

### Task 3.5: Cập nhật trạng thái crawl task

**Input:** `crawl_task_id`, `status`, `error_message`

**Output:** Record `crawl_tasks` được cập nhật

**Logic:**
1. Cập nhật `crawl_tasks`:
   - `status = 'done'` hoặc `'failed'`
   - `last_run = now()`
   - `error_message` (nếu failed)
   - `courses_count`, `sections_count`

---

## 🧮 4. Tích hợp Supabase

### Task 4.1: Setup Supabase Client

**Logic:**
```typescript
import { createClient } from '@supabase/supabase-js'
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
```

---

### Task 4.2: Upsert vào courses

**Input:** `{ code, name }`

**Logic:**
```typescript
await supabase
  .from('courses')
  .upsert(
    { code, name, updated_at: new Date() },
    { onConflict: 'code' }
  )
```

---

### Task 4.3: Upsert vào class_sections

**Input:** Toàn bộ fields của `class_sections`

**Logic:**
1. Tính `available_slots` (GENERATED COLUMN tự động)
2. Validate `days` là JSON hợp lệ
3. Upsert với conflict trên `register_code` hoặc `detail_url`

---

## 🤖 5. Tích hợp AI (Google AI Studio)

### Task 5.1: Thu thập thông tin người dùng

**Input từ người dùng:**
- Danh sách mã môn muốn đăng ký: Array<string>
- Nơi ở (campus): Quang Trung / Duy Tân / Hòa Khánh
- Khung giờ rảnh: [start, end] cho sáng/chiều/tối
- Giờ đi làm: [start, end] (optional)

**Output:** Object chuẩn hóa sẵn sàng gửi AI

---

### Task 5.2: Query lớp học từ Supabase

**Input:** `course_codes` (Array<string>)

**Logic:**
```typescript
const { data } = await supabase
  .from('class_sections')
  .select('*')
  .in('course_code', course_codes)
  .eq('status', 'Còn hạn')
  .gt('available_slots', 0)
```

**Output:** Array class sections với đầy đủ thông tin

---

### Task 5.3: Tạo prompt AI

**Input:** Thông tin người dùng + Dữ liệu lớp học

**Prompt Template:**
```
Bạn là trợ lý đăng ký tín chỉ cho sinh viên Đại học Duy Tân.

Thông tin sinh viên:
- Nơi ở: {campus}
- Khung giờ rảnh: {time_ranges}
- Giờ đi làm: {work_time} (nếu có)

Danh sách lớp học có sẵn:
{class_sections_json}

Yêu cầu:
1. Chọn các lớp học phù hợp nhất với khung giờ rảnh và nơi ở
2. Tránh xung đột thời gian giữa các lớp
3. Tránh overlap với giờ đi làm
4. Ưu tiên các lớp gần nơi ở
5. Nếu không có lớp phù hợp, đề xuất lớp thay thế

Trả về JSON:
{
  "recommended_sections": [{"register_code": "...", "reason": "..."}],
  "alternative_sections": [{"register_code": "...", "reason": "...", "warning": "..."}],
  "conflicts": [{"section_1": "...", "section_2": "...", "reason": "..."}]
}
```

---

### Task 5.4: Gọi Google AI Studio API

**Input:** Prompt string, API key

**Output:** JSON response từ AI

**Logic:**
1. Gọi Google AI Studio API
2. Parse JSON từ response
3. Validate format

---

### Task 5.5: Hiển thị kết quả

**Input:** AI response

**Output:** UI component hiển thị:
- Danh sách lớp được đề xuất (recommended_sections)
- Danh sách lớp thay thế (alternative_sections)
- Cảnh báo xung đột (conflicts)

---

## 🔁 6. Xử lý thay đổi dữ liệu

### Task 6.1: So sánh dữ liệu cũ và mới

**Input:** `old_data` (từ `class_sections`), `new_data` (từ crawl)

**Output:** Array of changes: `[{ field, old_value, new_value }]`

**Logic:**
1. So sánh các field quan trọng:
   - `lecturer`, `days`, `total_slots`, `registered_slots`, `available_slots`, `status`, `date_start`, `date_end`
2. Nếu khác nhau → thêm vào array changes
3. Ghi vào `crawl_logs` (Task 3.4)

---

## ⚙️ 7. Cấu trúc task tổng quan

### Phase 1: Setup Database
- Tạo schema Supabase (courses, class_sections, crawl_tasks, crawl_logs)
- Setup Supabase Client
- Tạo indexes

### Phase 2: Crawler Development
- Admin nhập URL
- Crawl danh sách môn học
- Crawl lớp học chi tiết
- Ghi log thay đổi
- Cập nhật crawl task

### Phase 3: UI Development
- Form thông tin cá nhân (mã môn, campus, giờ rảnh, giờ làm)
- Hiển thị kết quả AI

### Phase 4: AI Integration
- Thu thập thông tin người dùng
- Query lớp học từ Supabase
- Tạo prompt AI
- Gọi Google AI Studio API
- Parse và hiển thị kết quả

### Phase 5: Change Tracking
- So sánh dữ liệu (old vs new)
- Ghi log thay đổi vào crawl_logs

---

## 📘 8. Ghi chú phát triển

- **3 cơ sở**: Quang Trung, Duy Tân, Hòa Khánh
- **Cron job**: Nên tách crawler ra service riêng, chạy định kỳ (mỗi 6-12 giờ)
- **Performance**: Parallel processing, indexes, caching
- **Security**: RLS policies trên Supabase

---

## 📄 Metadata

**Tác giả:** Doan Vo Van Trong
**Ngày tạo:** 2025-11-02
**Phiên bản:** 1.0.0

---

## 🔗 Tài liệu tham khảo

- Supabase Documentation: https://supabase.com/docs
- Google AI Studio API: https://ai.google.dev/
- Nuxt 4 Documentation: https://nuxt.com/docs

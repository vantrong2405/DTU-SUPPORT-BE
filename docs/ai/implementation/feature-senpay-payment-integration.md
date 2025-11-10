---
phase: implementation
title: Implementation Guide
description: Technical implementation notes, patterns, and code guidelines
---

# Implementation Guide

## Development Setup
**How do we get started?**

### Prerequisites and dependencies
- Rails 8.0.2
- Supabase PostgreSQL database
- SenPay Sandbox account credentials
- ngrok hoặc staging server cho webhook testing

### Environment setup steps
1. Lấy SenPay Sandbox credentials từ SenPay dashboard
2. Thêm vào `.env` file:
   ```
   SENPAY_MERCHANT_ID=your_merchant_id
   SENPAY_SECRET_KEY=your_secret_key
   SENPAY_API_URL=https://pgapi-sandbox.sepay.vn
   SENPAY_CHECKOUT_URL=https://pay-sandbox.sepay.vn/v1/checkout/init
   SENPAY_REDIRECT_URL=http://localhost:3000/payment/return
   SENPAY_WEBHOOK_URL=https://xxxx.ngrok.io/api/webhooks/senpay
   ```
3. Update `.env.example` với SenPay variables (không có values)
4. Run `bundle install` để đảm bảo dependencies

### Configuration needed
- SenPay credentials trong environment variables
- Webhook URL phải accessible từ internet (HTTPS)
- Payment timeout: 15 minutes (900 seconds)

## Code Structure
**How is the code organized?**

### Directory structure
```
app/
├── controllers/
│   ├── payments_controller.rb
│   └── webhooks/
│       └── senpay_controller.rb
├── services/
│   ├── senpay/
│   │   └── client.rb
│   ├── payments/
│   │   ├── create_payment_service.rb
│   │   └── process_webhook_service.rb
│   └── subscriptions/
│       ├── activate_service.rb
│       └── request_limit_service.rb
└── models/
    ├── payment.rb (existing, may need enhancements)
    ├── subscription_plan.rb (existing)
    └── user.rb (existing, may need enhancements)
```

### Module organization
- **Services**: Business logic layer, extend `Services::BaseService`
- **Controllers**: Thin layer, delegate to services, use `Renderable` concern
- **Models**: Data layer, validations, associations

### Naming conventions
- Services: `[Domain]::[Action]Service` (e.g., `Payments::CreatePaymentService`)
- Controllers: `[Resource]Controller` (e.g., `PaymentsController`)
- Methods: snake_case, descriptive names

## Implementation Notes
**Key technical details to remember:**

### Core Features

#### 1. SenPay Client Service
**File**: `app/services/senpay/client.rb`

```ruby
class Senpay::Client < BaseService
  def initialize
    @merchant_id = ENV.fetch('SENPAY_MERCHANT_ID')
    @secret_key = ENV.fetch('SENPAY_SECRET_KEY')
    @api_url = ENV.fetch('SENPAY_API_URL')
    @checkout_url = ENV.fetch('SENPAY_CHECKOUT_URL')
  end

  def create_payment_request(params)
    # Build form params
    # Generate signature
    # Return form data
  end

  def build_signature(params)
    # Build signature string from params
    # HMAC SHA256 with secret_key
    # Base64 encode
    # Return signature
  end

  def verify_webhook_signature(params, signature)
    # Build expected signature
    # Compare with received signature
    # Return boolean
  end
end
```

**Key points:**
- Signature generation: HMAC SHA256 với secret_key, sau đó Base64 encode
- Basic Authentication: `Authorization: Basic base64(merchant_id:secret_key)`
- Request format: HTML Form với POST method
- Error handling: Handle SenPay API errors gracefully

#### 2. Payment Creation Service
**File**: `app/services/payments/create_payment_service.rb`

```ruby
class Payments::CreatePaymentService < Services::BaseService
  def call(user:, subscription_plan:, payment_method:)
    # Validate inputs
    # Create payment record (status: pending)
    # Call SenPay Client to create payment request
    # Generate HTML form with signature
    # Save form data to transaction_data
    # Set expired_at (15 minutes from now)
    # Return payment object with form data
  end
end
```

**Key points:**
- Payment status: "pending" initially
- Expired_at: 15 minutes from creation
- Transaction_data: Store SenPay form data in JSONB
- Form generation: Create HTML form với signature để submit đến SenPay

#### 3. Webhook Processing Service
**File**: `app/services/payments/process_webhook_service.rb`

```ruby
class Payments::ProcessWebhookService < Services::BaseService
  def call(webhook_params)
    # Verify signature
    # Find payment by order_invoice_number
    # Check if already processed (idempotent)
    # Update payment status và transaction_data
    # If success: Trigger subscription activation
    # Return success/failure
  end
end
```

**Key points:**
- Idempotent: Check payment status trước khi update
- Signature verification: Bắt buộc, reject nếu invalid
- Subscription activation: Chỉ trigger khi payment success
- Response: HTTP 200 với `{"success": true}` để xác nhận

#### 4. Subscription Activation Service
**File**: `app/services/subscriptions/activate_service.rb`

```ruby
class Subscriptions::ActivateService < Services::BaseService
  def call(user:, subscription_plan:, payment:)
    # Update user.subscription_plan_id
    # Calculate expired_at from subscription_plan.duration_days
    # Update payment.expired_at
    # Log activation
    # Return activated subscription
  end
end
```

**Key points:**
- Expired_at calculation: `Time.current + subscription_plan.duration_days.days`
- Transaction: Wrap trong transaction để đảm bảo consistency
- Error handling: Rollback nếu activation fails

#### 5. Request Limit Service
**File**: `app/services/subscriptions/request_limit_service.rb`

```ruby
class Subscriptions::RequestLimitService < Services::BaseService
  def remaining_requests(user)
    # Get limit from subscription_plan.features['ai_limit']
    # Get used count (from tracking table hoặc cache)
    # Return remaining count
  end

  def can_use_ai_chatbox?(user)
    # Check if user has active subscription
    # Check if remaining_requests > 0
    # Return boolean
  end

  def consume_request(user)
    # Decrement request count
    # Update tracking table hoặc cache
    # Return success/failure
  end
end
```

**Key points:**
- Request limit: Lấy từ `subscription_plan.features['ai_limit']`
- Usage tracking: Có thể dùng separate table hoặc cache

### Patterns & Best Practices
- **Service Object Pattern**: Business logic trong services
- **Repository Pattern**: Database access qua ActiveRecord models
- **Idempotency**: Webhook processing phải idempotent
- **Error Handling**: Comprehensive error handling và logging

## Integration Points
**How do pieces connect?**

### API integration details
- **SenPay Checkout API**: POST form với signature
- **SenPay Webhook API**: POST JSON với notification_type
- **SenPay Query API**: GET với Basic Authentication

### Database connections
- **payments** table: Lưu payment records và transaction_data (JSONB)
- **users** table: Lưu subscription_plan_id
- **subscription_plans** table: Lưu plan features với ai_limit

### Third-party service setup
- **SenPay Payment Gateway**: Sandbox environment integration
- **Webhook endpoint**: Phải accessible từ internet (ngrok cho development)

## Error Handling
**How do we handle failures?**

### Error handling strategy
- **Payment Creation**: Return error message, log error
- **Webhook Processing**: Return HTTP 200 với error message, log error
- **Subscription Activation**: Rollback transaction, log error

### Logging approach
- Log tất cả payment operations
- Log webhook processing attempts
- Log errors với full stack trace

### Retry/fallback mechanisms
- Retry logic cho SenPay API calls (3 lần với exponential backoff)
- Webhook retry: SenPay tự động retry nếu không nhận được HTTP 200

## Performance Considerations
**How do we keep it fast?**

### Optimization strategies
- Cache subscription plan features
- Optimize database queries (no N+1)
- Background job cho webhook processing (nếu cần)

### Caching approach
- Cache subscription plan data
- Cache user subscription status

### Query optimization
- Use includes để tránh N+1 queries
- Add indexes cho payment lookups

## Security Notes
**What security measures are in place?**

### Authentication/authorization
- Basic Authentication cho SenPay API calls
- Webhook signature verification
- User authentication cho payment endpoints

### Input validation
- Validate payment parameters
- Validate webhook data
- Sanitize user input

### Data encryption
- HTTPS cho webhook endpoint
- Sensitive data (SenPay credentials) lưu trong environment variables

### Secrets management
- SenPay credentials lưu trong `.env` file
- Không commit `.env` file vào git

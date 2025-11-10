---
phase: planning
title: Project Planning & Task Breakdown
description: Break down work into actionable tasks and estimate timeline
---

# Project Planning & Task Breakdown

## Milestones
**What are the major checkpoints?**

- [ ] Milestone 1: SenPay Client Integration - Hoàn thành tích hợp SenPay API client và signature generation
- [ ] Milestone 2: Payment Flow - Hoàn thành payment creation và checkout flow
- [ ] Milestone 3: IPN/Webhook Processing - Hoàn thành webhook callback handling và subscription activation
- [ ] Milestone 4: Migration from MoMo - Thay thế hoàn toàn code MoMo bằng SenPay
- [ ] Milestone 5: Testing & Documentation - Hoàn thành testing và documentation

## Task Breakdown
**What specific work needs to be done?**

### Phase 0: Database Setup & Configuration
- [ ] Task 0.1: Create database migration for SenPay transaction data
  - Tạo migration để thêm fields cho SenPay transaction data vào `payments` table
  - Hoặc tạo bảng `senpay_transactions` (theo SenPay recommendation)
  - Fields: gateway, transaction_date, amount_in, amount_out, code, transaction_content, reference_number, body
  - Add indexes cho idempotency check
- [ ] Task 0.2: Setup SenPay environment variables
  - Thêm SenPay variables vào `.env.example`
  - Thêm SenPay variables vào `.env.development`
  - Variables: SENPAY_MERCHANT_ID, SENPAY_SECRET_KEY, SENPAY_API_URL, SENPAY_REDIRECT_URL, SENPAY_WEBHOOK_URL
- [ ] Task 0.3: Create SenPay initializer
  - Tạo `config/initializers/senpay.rb`
  - Load SenPay credentials từ ENV
  - Validate required environment variables

### Phase 1: SenPay Client Service
- [ ] Task 1.1: Create SenPay Client service
  - Tạo `app/services/senpay/client.rb`
  - Implement Basic Authentication (merchant_id:secret_key)
  - Implement `build_signature(params)` method (HMAC SHA256 + Base64)
  - Implement `create_payment_request(params)` method
  - Implement `verify_webhook_signature(params, signature)` method
  - Handle SenPay API errors
- [ ] Task 1.2: Add HTTP client for SenPay API calls
  - Sử dụng `Net::HTTP` hoặc `Faraday`
  - Implement POST request với Basic Auth
  - Handle timeout và retry logic
- [ ] Task 1.3: Implement signature generation
  - Build signature string từ form params (theo thứ tự SenPay quy định)
  - Generate HMAC SHA256 signature với secret_key
  - Encode Base64
  - Return signature string

### Phase 2: Payment Service & Controller
- [ ] Task 2.1: Update Payment Service
  - Update `app/services/payments/create_payment_service.rb`
  - Thay `create_momo_request` → `create_senpay_request`
  - Generate HTML form với signature
  - Return form data hoặc checkout URL
- [ ] Task 2.2: Update Payments Controller
  - Update `app/controllers/payments_controller.rb`
  - Update `payment_method` default từ "momo" → "senpay"
  - Update serialization để return form data
- [ ] Task 2.3: Add payment routes
  - Thêm routes trong `config/routes.rb` (nếu cần)
  - Routes: `POST /payments`, `GET /payments/:id`, `GET /payments`

### Phase 3: IPN/Webhook Processing
- [ ] Task 3.1: Create Webhook Controller
  - Tạo `app/controllers/webhooks/senpay_controller.rb`
  - Implement `callback` action (POST /api/webhooks/senpay)
  - Skip authentication (webhook từ SenPay)
  - Add rate limiting (tránh abuse)
- [ ] Task 3.2: Create Payment Webhook Service
  - Tạo `app/services/payments/process_webhook_service.rb`
  - Implement `call(webhook_params)` method
  - Verify webhook signature
  - Find payment by order_invoice_number
  - Update payment status và transaction_data
  - Handle duplicate webhooks (idempotent)
  - Return success/failure
- [ ] Task 3.3: Add webhook routes
  - Thêm route trong `config/routes.rb`
  - Route: `POST /api/webhooks/senpay`
  - Skip CSRF protection (webhook từ external service)

### Phase 4: Subscription Activation
- [ ] Task 4.1: Update Subscription Activation Service
  - Update `app/services/subscriptions/activate_service.rb` (nếu cần)
  - Ensure integration với SenPay payment flow
- [ ] Task 4.2: Integrate activation vào webhook service
  - Call Subscription Activation Service khi payment success
  - Handle activation errors (rollback payment status nếu cần)
  - Add logging cho activation flow

### Phase 5: Migration from MoMo
- [ ] Task 5.1: Remove MoMo code
  - Xóa `app/services/momo/client.rb`
  - Xóa `app/controllers/webhooks/momo_controller.rb`
  - Xóa `config/initializers/momo.rb`
  - Xóa MoMo routes
- [ ] Task 5.2: Update Payment Service
  - Remove MoMo references
  - Update payment_method validation
  - Update error messages
- [ ] Task 5.3: Update environment variables
  - Xóa MoMo variables từ `.env.example`
  - Xóa MoMo variables từ `.env.development`
  - Update env_validator nếu cần

### Phase 6: Error Handling & Edge Cases
- [ ] Task 6.1: Handle payment timeout
  - Check expired payments
  - Update status to "expired" nếu quá timeout
  - Background job để check expired payments (optional)
- [ ] Task 6.2: Handle payment failures
  - Update payment status to "failed"
  - Log error details
  - Return appropriate error messages
- [ ] Task 6.3: Handle duplicate webhooks
  - Idempotent webhook processing
  - Check payment status trước khi update
  - Skip nếu đã processed
- [ ] Task 6.4: Handle network errors
  - Retry logic cho SenPay API calls
  - Error handling cho webhook processing
  - Logging cho debugging

### Phase 7: Testing
- [ ] Task 7.1: Unit tests cho SenPay Client
  - Test signature generation
  - Test signature verification
  - Test API call methods
  - Test Basic Authentication
- [ ] Task 7.2: Unit tests cho Payment Service
  - Test payment creation
  - Test error handling
  - Test form generation
- [ ] Task 7.3: Unit tests cho Webhook Service
  - Test webhook processing
  - Test signature verification
  - Test duplicate webhook handling
  - Test idempotency
- [ ] Task 7.4: Integration tests
  - Test payment creation flow
  - Test webhook callback flow
  - Test subscription activation flow
- [ ] Task 7.5: Manual testing
  - Test với SenPay Sandbox environment
  - Test payment flow end-to-end
  - Test webhook callback với ngrok

### Phase 8: Documentation & Cleanup
- [ ] Task 8.1: Update API documentation
  - Document payment endpoints
  - Document webhook endpoint
  - Document request/response formats
- [ ] Task 8.2: Add code comments
  - Comment complex logic
  - Document service methods
- [ ] Task 8.3: Update README hoặc docs
  - Document SenPay integration setup
  - Document environment variables
  - Document webhook setup

## Dependencies
**What needs to happen in what order?**

### Task dependencies and blockers
- **Phase 0** (Database & Config) → **Phase 1** (SenPay Client): Cần credentials và database structure trước
- **Phase 1** (SenPay Client) → **Phase 2** (Payment Service): Cần client trước khi tạo payment
- **Phase 2** (Payment Service) → **Phase 3** (Webhook): Cần payment creation trước khi xử lý webhook
- **Phase 3** (Webhook) → **Phase 4** (Subscription Activation): Cần webhook processing trước khi activate subscription
- **Phase 5** (Migration) có thể làm song song với các phases khác
- **Phase 6** (Error Handling) có thể làm song song với các phases khác
- **Phase 7** (Testing) nên làm sau khi hoàn thành các phases chính
- **Phase 8** (Documentation) làm cuối cùng

### External dependencies (APIs, services, etc.)
- **SenPay Payment Gateway**: Sandbox environment API và credentials
- **Webhook endpoint**: Phải accessible từ internet (ngrok hoặc staging server)
- **SenPay API documentation**: Cần đầy đủ và cập nhật

### Team/resource dependencies
- Access to SenPay Sandbox account và credentials
- Staging server hoặc ngrok để test webhook
- SenPay API documentation access

## Timeline & Estimates
**When will things be done?**

### Estimated effort per task/phase
- **Phase 0** (Database & Config): 2-3 hours
- **Phase 1** (SenPay Client): 4-6 hours
- **Phase 2** (Payment Service): 3-4 hours
- **Phase 3** (Webhook Processing): 4-6 hours
- **Phase 4** (Subscription Activation): 1-2 hours (update existing)
- **Phase 5** (Migration from MoMo): 2-3 hours
- **Phase 6** (Error Handling): 3-4 hours
- **Phase 7** (Testing): 6-8 hours
- **Phase 8** (Documentation): 2-3 hours

**Total estimated effort**: 27-39 hours (~3-5 working days)

### Target dates for milestones
- **Milestone 1** (SenPay Client): Day 1-2
- **Milestone 2** (Payment Flow): Day 2-3
- **Milestone 3** (Webhook Processing): Day 3-4
- **Milestone 4** (Migration): Day 4-5
- **Milestone 5** (Testing & Documentation): Day 5

### Buffer for unknowns
- SenPay API documentation có thể không đầy đủ: +2 hours
- Webhook testing có thể phức tạp: +2 hours
- Edge cases có thể phát sinh: +3 hours
- **Total buffer**: ~7 hours

## Risks & Mitigation
**What could go wrong?**

### Technical risks
- **Risk**: SenPay API documentation không đầy đủ hoặc không cập nhật
  - **Mitigation**: Liên hệ SenPay support, test thử với Sandbox environment
- **Risk**: Webhook signature verification phức tạp
  - **Mitigation**: Test kỹ với SenPay Sandbox, đọc kỹ documentation
- **Risk**: HTML form approach khác với MoMo JSON API
  - **Mitigation**: Study SenPay documentation kỹ, test với Sandbox
- **Risk**: IPN URL phải là HTTPS (khó test local)
  - **Mitigation**: Dùng ngrok cho development, staging server cho testing

### Resource risks
- **Risk**: Không có access đến SenPay Sandbox account
  - **Mitigation**: Yêu cầu access sớm, có thể mock SenPay API cho development
- **Risk**: Webhook endpoint không accessible từ internet
  - **Mitigation**: Dùng ngrok cho development, staging server cho testing

### Dependency risks
- **Risk**: SenPay API thay đổi hoặc downtime
  - **Mitigation**: Implement retry logic, error handling tốt
- **Risk**: Migration từ MoMo có thể break existing functionality
  - **Mitigation**: Test kỹ trước khi deploy, có rollback plan

### Mitigation strategies
- Test early và often với SenPay Sandbox environment
- Implement comprehensive error handling
- Logging đầy đủ cho debugging
- Code review trước khi merge
- Manual testing kỹ trước khi deploy

## Resources Needed
**What do we need to succeed?**

### Team members and roles
- Backend developer: Implement payment integration
- QA: Test payment flow và webhook
- DevOps: Setup webhook endpoint (nếu cần)

### Tools and services
- SenPay Sandbox account và credentials
- ngrok hoặc staging server cho webhook testing
- SenPay API documentation
- Postman hoặc similar tool để test SenPay API

### Infrastructure
- Staging server để test webhook (hoặc ngrok)
- Database access (Supabase PostgreSQL)
- Environment variables setup

### Documentation/knowledge
- SenPay API documentation: https://developer.sepay.vn/
- SenPay Webhooks guide: https://docs.sepay.vn/tich-hop-webhooks.html
- Project codebase knowledge (payment, subscription models)

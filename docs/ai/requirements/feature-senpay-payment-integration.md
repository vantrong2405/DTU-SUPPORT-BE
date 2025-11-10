---
phase: requirements
title: Requirements & Problem Understanding
description: Clarify the problem space, gather requirements, and define success criteria
---

# Requirements & Problem Understanding

## Problem Statement
**What problem are we solving?**

- Hiện tại hệ thống đang sử dụng MoMo Payment Gateway, cần thay thế hoàn toàn bằng SenPay Payment Gateway
- Người dùng cần thanh toán để mua subscription plan và nhận giới hạn số lượng request cho AI chatbox
- Cần tích hợp SenPay Payment Gateway trên môi trường Sandbox để cho phép người dùng thanh toán và kích hoạt subscription plan
- Sau khi thanh toán thành công, user cần được cấp subscription plan với giới hạn request tương ứng để sử dụng AI chatbox

**Who is affected by this problem?**
- End users: Cần thanh toán để sử dụng các tính năng premium (AI chatbox với giới hạn request)
- System administrators: Cần quản lý thanh toán và subscription
- Developers: Cần migrate từ MoMo sang SenPay

**What is the current situation/workaround?**
- Hiện tại đang sử dụng MoMo Payment Gateway
- Cần thay thế hoàn toàn code và configuration liên quan đến MoMo
- Cần tích hợp SenPay với cơ chế tương tự nhưng API khác

## Goals & Objectives
**What do we want to achieve?**

### Primary goals
- Tích hợp SenPay Payment Gateway (Sandbox environment) vào hệ thống
- Thay thế hoàn toàn MoMo bằng SenPay
- Cho phép user thanh toán subscription plan qua SenPay
- Tự động kích hoạt subscription plan cho user sau khi thanh toán thành công
- Cấp giới hạn số lượng request (từ features của plan) cho user để sử dụng AI chatbox
- Lưu trữ thông tin giao dịch và transaction data từ SenPay
- Xử lý IPN/Webhook từ SenPay để cập nhật trạng thái thanh toán

### Secondary goals
- Hỗ trợ webhook callback từ SenPay để xử lý payment status
- Logging và tracking payment transactions
- Hỗ trợ xử lý các trường hợp edge cases (payment timeout, failed payment, etc.)
- Đối soát giao dịch qua API query

### Non-goals (what's explicitly out of scope)
- Tích hợp production SenPay environment (chỉ Sandbox)
- Hỗ trợ các payment gateway khác (chỉ SenPay)
- Refund processing (có thể làm sau)
- Payment retry mechanism tự động (có thể làm sau)

## User Stories & Use Cases
**How will users interact with the solution?**

### User Story 1: Thanh toán subscription plan
- **As a** user
- **I want to** thanh toán subscription plan qua SenPay
- **So that** tôi có thể nhận được giới hạn số lượng request để sử dụng AI chatbox

### User Story 2: Nhận subscription sau thanh toán
- **As a** user
- **I want to** tự động nhận subscription plan sau khi thanh toán thành công
- **So that** tôi có thể sử dụng ngay các tính năng premium

### User Story 3: Xem lịch sử thanh toán
- **As a** user
- **I want to** xem lịch sử thanh toán của mình
- **So that** tôi có thể theo dõi các giao dịch đã thực hiện

### Key workflows and scenarios

**Workflow 1: Payment Flow**
1. User chọn subscription plan
2. User chọn phương thức thanh toán SenPay
3. System tạo payment record với status "pending"
4. System tạo form HTML với signature và redirect user đến SenPay payment page (Sandbox)
5. User thanh toán trên SenPay
6. SenPay gửi IPN/Webhook callback về system
7. System xử lý callback và update payment status
8. Nếu thành công: System kích hoạt subscription plan cho user và cấp giới hạn request

**Workflow 2: IPN/Webhook Callback Flow**
1. SenPay gửi POST request đến IPN endpoint (HTTPS)
2. System verify signature/authentication
3. System update payment status và transaction_data
4. System kích hoạt subscription plan nếu payment thành công
5. System trả về HTTP 200 với {"success": true} để xác nhận

**Workflow 3: Query Transaction Flow (Đối soát)**
1. System gọi SenPay API để query transaction status
2. System đối soát với database
3. System cập nhật nếu có thay đổi

### Edge cases to consider
- Payment timeout: User không hoàn tất thanh toán trong thời gian quy định
- Payment failed: Thanh toán thất bại do lỗi từ SenPay hoặc user
- Duplicate webhook: SenPay gửi nhiều webhook cho cùng một transaction (retry mechanism)
- Network error: Mất kết nối khi xử lý webhook
- Invalid signature: Webhook không hợp lệ hoặc bị giả mạo
- Payment success nhưng subscription activation failed: Cần rollback hoặc retry mechanism
- IPN URL không accessible: Cần dùng ngrok cho development

## Success Criteria
**How will we know when we're done?**

### Measurable outcomes
- User có thể thanh toán subscription plan qua SenPay (Sandbox environment)
- Payment status được update chính xác (pending → success/failed)
- Subscription plan được kích hoạt tự động sau khi thanh toán thành công
- User nhận được giới hạn request từ subscription plan features
- IPN/Webhook callback được xử lý thành công với rate > 95%
- Payment transaction được lưu trữ đầy đủ trong database
- Code MoMo đã được thay thế hoàn toàn bằng SenPay

### Acceptance criteria
- [ ] API endpoint tạo payment request và redirect đến SenPay
- [ ] IPN/Webhook endpoint nhận và xử lý callback từ SenPay
- [ ] Payment status được update chính xác
- [ ] Subscription plan được kích hoạt tự động sau payment success
- [ ] User nhận được giới hạn request từ plan features
- [ ] Transaction data được lưu vào `payments.transaction_data`
- [ ] Error handling cho các edge cases
- [ ] Logging cho payment flow và webhook processing
- [ ] Code MoMo đã được xóa/thay thế hoàn toàn

### Performance benchmarks (if applicable)
- Webhook processing time < 2 seconds
- Payment creation API response time < 500ms
- Database queries optimized (no N+1 queries)

## Constraints & Assumptions
**What limitations do we need to work within?**

### Technical constraints
- Chỉ tích hợp SenPay Sandbox environment (không production)
- Rails 8.0.2 API-only application
- Supabase PostgreSQL database
- Phải tuân thủ SenPay API documentation và requirements
- IPN/Webhook endpoint phải là HTTPS (dùng ngrok cho development)
- SenPay sử dụng Basic Authentication (merchant_id:secret_key)

### Business constraints
- Chỉ hỗ trợ VND currency
- Payment timeout: 15 phút (theo SenPay standard)
- Subscription plan features phải có field `ai_limit` hoặc tương tự

### Time/budget constraints
- Cần hoàn thành trong thời gian hợp lý
- Ưu tiên Sandbox environment trước, production sau

### Assumptions we're making
- SenPay Sandbox credentials đã có sẵn hoặc có thể đăng ký
- SenPay API documentation đầy đủ và cập nhật
- IPN/Webhook endpoint có thể được expose ra internet (qua ngrok hoặc staging server)
- Subscription plan model đã có sẵn và hoạt động
- User model đã có relationship với subscription_plan và payments

## Questions & Open Items
**What do we still need to clarify?**

### ✅ Clarified Items

#### 1. SenPay Sandbox Environment Credentials
**Status**: ✅ Clarified - Cần lấy từ SenPay Developer Portal
- **Merchant ID**: Lấy từ SenPay Dashboard sau khi đăng ký
- **Secret Key**: Lấy từ SenPay Dashboard (dùng cho signature generation)
- **Action Required**: Đăng ký tài khoản tại https://developer.sepay.vn/ và lấy credentials
- **Storage**: Lưu trong `.env` file với prefix `SENPAY_`

#### 2. SenPay API Endpoint URLs
**Status**: ✅ Clarified - Từ SenPay documentation
- **Sandbox Base URL**: `https://pgapi-sandbox.sepay.vn`
- **Checkout Endpoint**: `https://pay-sandbox.sepay.vn/v1/checkout/init`
- **IPN/Webhook URL**: Phải là HTTPS, accessible từ internet (dùng ngrok cho development)
- **Action Required**: Verify endpoint URLs khi có credentials

#### 3. SenPay Authentication
**Status**: ✅ Clarified - Basic Authentication
- **Method**: Basic Authentication với `merchant_id:secret_key`
- **Header**: `Authorization: Basic base64(merchant_id:secret_key)`
- **Content-Type**: `application/json`
- **Action Required**: Implement Basic Auth trong SenPay Client

#### 4. SenPay Signature Generation
**Status**: ✅ Clarified - HMAC SHA256
- **Method**: HMAC SHA256 với secret_key
- **Process**:
  1. Build signature string từ form params (theo thứ tự SenPay quy định)
  2. Generate HMAC SHA256 signature với secret_key
  3. Encode Base64
- **Action Required**: Implement signature generation trong SenPay Client

#### 5. SenPay IPN/Webhook Processing
**Status**: ✅ Clarified - POST JSON với notification_type
- **Method**: POST request với JSON body
- **Notification Type**: `ORDER_PAID` cho thanh toán thành công
- **Response**: HTTP 200 với `{"success": true}` để xác nhận
- **Idempotency**: Kiểm tra tính duy nhất của transaction id để tránh duplicate processing
- **Action Required**: Implement IPN endpoint và processing logic

#### 6. Database Structure for Webhooks
**Status**: ✅ Clarified - Từ SenPay documentation
- **Table**: `tb_transactions` (theo SenPay recommendation) hoặc sử dụng `payments` table hiện có
- **Fields**: gateway, transaction_date, amount_in, amount_out, code, transaction_content, reference_number, body
- **Idempotency**: Kiểm tra duplicate bằng transaction id hoặc kết hợp referenceCode, transferType, transferAmount
- **Action Required**: Tạo migration hoặc update payments table để lưu SenPay transaction data

#### 7. IPN URL cho Development
**Status**: ✅ Clarified - Dùng ngrok
- **Requirement**: IPN URL phải là HTTPS
- **Solution**: Dùng ngrok để expose local server ra internet
- **Process**:
  1. Chạy `ngrok http 3000`
  2. Copy HTTPS URL: `https://xxxx.ngrok.io`
  3. Cấu hình IPN URL: `https://xxxx.ngrok.io/api/webhooks/senpay`
- **Action Required**: Setup ngrok và cấu hình IPN URL trong SenPay Dashboard

#### 8. Subscription Activation Mechanism
**Status**: ✅ Clarified - Set `user.subscription_plan_id` directly
- **Method**: Set `user.subscription_plan_id = subscription_plan.id` trực tiếp
- **Additional Logic**:
  - Calculate `payment.expired_at` từ `subscription_plan.duration_days`
  - Grant request limit từ `subscription_plan.features['ai_limit']`
- **Transaction**: Wrap trong database transaction để đảm bảo consistency
- **Action Required**: Implement trong `Subscriptions::ActivateService`

#### 9. Migration từ MoMo sang SenPay
**Status**: ✅ Clarified - Thay thế hoàn toàn
- **Code**: Xóa/thay thế tất cả code liên quan đến MoMo
- **Configuration**: Xóa MoMo environment variables, thêm SenPay variables
- **Services**: Thay `Momo::Client` bằng `Senpay::Client`
- **Controllers**: Update webhook controller từ MoMo sang SenPay
- **Action Required**: Refactor code để thay thế MoMo bằng SenPay

### 📋 Action Items Summary

**Before Implementation:**
1. ✅ Đăng ký SenPay Developer account và lấy credentials
2. ✅ Đọc SenPay API documentation (Sandbox environment)
3. ✅ Verify SenPay API endpoints cho Sandbox
4. ✅ Setup ngrok hoặc staging server cho IPN testing
5. ✅ Ensure subscription plans có `ai_limit` trong features

**During Implementation:**
1. ✅ Implement signature generation và verification
2. ✅ Implement idempotent webhook processing
3. ✅ Implement transaction-based subscription activation
4. ✅ Add comprehensive logging
5. ✅ Handle edge cases (timeout, duplicate webhooks, etc.)
6. ✅ Thay thế code MoMo bằng SenPay

**After Implementation:**
1. ✅ Test với SenPay Sandbox environment
2. ✅ Verify IPN/Webhook processing
3. ✅ Test subscription activation flow
4. ✅ Document any deviations từ SenPay documentation

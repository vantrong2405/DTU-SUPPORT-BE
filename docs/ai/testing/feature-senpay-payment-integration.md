---
phase: testing
title: Testing Strategy
description: Define testing approach, test cases, and quality assurance
---

# Testing Strategy

## Test Coverage Goals
**What level of testing do we aim for?**

- Unit test coverage target: 100% of new/changed code
- Integration test scope: Critical paths + error handling
- End-to-end test scenarios: Key user journeys
- Alignment with requirements/design acceptance criteria

## Unit Tests
**What individual components need testing?**

### SenPay Client Service
- [ ] Test signature generation (HMAC SHA256 + Base64)
  - Test với các params khác nhau
  - Test signature string format
  - Test Base64 encoding
- [ ] Test signature verification
  - Test valid signature
  - Test invalid signature
  - Test missing signature
- [ ] Test Basic Authentication
  - Test header format
  - Test Base64 encoding của merchant_id:secret_key
- [ ] Test API call methods
  - Test create_payment_request
  - Test query_order_status
  - Test error handling

### Payment Service
- [ ] Test payment creation
  - Test với valid inputs
  - Test với invalid inputs
  - Test error handling
- [ ] Test form generation
  - Test form data structure
  - Test signature inclusion
  - Test all required fields
- [ ] Test error handling
  - Test SenPay API errors
  - Test validation errors
  - Test timeout handling

### Webhook Service
- [ ] Test webhook processing
  - Test với valid webhook data
  - Test với invalid webhook data
  - Test với missing fields
- [ ] Test signature verification
  - Test valid signature
  - Test invalid signature
  - Test missing signature
- [ ] Test duplicate webhook handling
  - Test idempotency
  - Test duplicate detection
  - Test skip processing nếu đã processed
- [ ] Test payment status update
  - Test update to success
  - Test update to failed
  - Test transaction_data update

### Subscription Activation Service
- [ ] Test subscription activation
  - Test với valid payment
  - Test với invalid payment
  - Test error handling
- [ ] Test request limit granting
  - Test limit calculation
  - Test limit storage

## Integration Tests
**How do we test component interactions?**

- [ ] Integration scenario 1: Payment creation flow
  - Test payment creation → form generation → redirect
  - Test error handling
- [ ] Integration scenario 2: Webhook callback flow
  - Test webhook → payment update → subscription activation
  - Test error handling
- [ ] Integration scenario 3: Subscription activation flow
  - Test payment success → activation → limit granting
  - Test rollback nếu activation fails
- [ ] API endpoint tests
  - Test POST /api/payments
  - Test GET /api/payments/:id
  - Test POST /api/webhooks/senpay

## End-to-End Tests
**What user flows need validation?**

- [ ] User flow 1: Complete payment flow
  - User selects plan → creates payment → redirects to SenPay → pays → webhook received → subscription activated
- [ ] User flow 2: Payment failure flow
  - User creates payment → redirects to SenPay → payment fails → webhook received → payment status updated
- [ ] User flow 3: Webhook retry flow
  - Webhook received → processed → duplicate webhook received → skipped
- [ ] Critical path testing
  - Test payment creation
  - Test webhook processing
  - Test subscription activation

## Test Data
**What data do we use for testing?**

### Test fixtures and mocks
- Mock SenPay API responses
- Mock webhook payloads
- Test payment records
- Test subscription plans

### Seed data requirements
- Subscription plans với features
- Test users
- Test payments

### Test database setup
- Use test database
- Clean up after tests
- Use factories cho test data

## Test Reporting & Coverage
**How do we verify and communicate test results?**

- Coverage commands: `bundle exec rspec --coverage`
- Coverage thresholds: 100% for new code
- Test reports: Generate coverage reports
- Manual testing outcomes: Document manual test results

## Manual Testing
**What requires human validation?**

- [ ] UI/UX testing checklist
  - Test payment form display
  - Test redirect to SenPay
  - Test return from SenPay
- [ ] Browser/device compatibility
  - Test trên các browsers khác nhau
  - Test trên mobile devices
- [ ] Smoke tests after deployment
  - Test payment creation
  - Test webhook processing
  - Test subscription activation

## Performance Testing
**How do we validate performance?**

- [ ] Load testing scenarios
  - Test payment creation under load
  - Test webhook processing under load
- [ ] Stress testing approach
  - Test với nhiều concurrent requests
- [ ] Performance benchmarks
  - Payment creation: < 500ms
  - Webhook processing: < 2 seconds

## Bug Tracking
**How do we manage issues?**

- Issue tracking process: Document bugs trong GitHub issues
- Bug severity levels: Critical, High, Medium, Low
- Regression testing strategy: Run full test suite trước khi merge

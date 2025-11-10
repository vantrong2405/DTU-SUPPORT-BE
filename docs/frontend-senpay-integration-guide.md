# Frontend SenPay Integration Guide

## Tổng quan

Hướng dẫn tích hợp SenPay payment gateway vào Frontend application. **Backend đã config tất cả**, Frontend chỉ cần submit form.

**Thay đổi quan trọng:**
- ✅ **Backend config tất cả** - BE đã tạo form data với signature (không cần FE config gì)
- ✅ **Frontend chỉ cần submit form** - FE chỉ cần tạo form và submit với form_data từ BE
- ✅ **Không cần tạo signature** - Backend đã tạo signature sẵn trong form_data
- ✅ **Đơn giản hơn** - FE không cần biết cách tạo signature hay config gì

---

## Payment Flow

```
1. User chọn subscription plan
2. Frontend gọi POST /payments → Backend:
   - Tạo payment record
   - Tạo form data với signature (BE config tất cả)
   - Trả về checkout_url + form_data cho Frontend
3. Frontend tạo form và submit với form_data (BE đã config sẵn)
4. User thanh toán trên SenPay
5. SenPay redirect user về return_url (frontend)
6. SenPay gửi webhook đến backend (tự động)
7. Frontend hiển thị kết quả thanh toán
```

**Lưu ý:** Backend đã xử lý tất cả logic phức tạp (signature generation, form data creation), Frontend chỉ cần submit form.

---

## API Endpoints

### 0. Lấy danh sách Subscription Plans (BẮT BUỘC gọi trước)

**Endpoint:** `GET /subscription-plans`

**Authentication:** Không cần

**Response (Success - 200):**
```json
{
  "data": [
    {
      "id": 7,
      "type": "subscription_plan",
      "attributes": {
        "id": 7,
        "name": "Gói Basic",
        "price": 100000.0,
        "duration_days": 30,
        "features": {
          "ai_limit": 50,
          "crawl_limit": 20
        },
        "ai_limit": 50,
        "crawl_limit": 20,
        "created_at": "2025-11-08T02:00:00Z",
        "updated_at": "2025-11-08T02:00:00Z"
      }
    },
    {
      "id": 8,
      "type": "subscription_plan",
      "attributes": {
        "id": 8,
        "name": "Gói Pro",
        "price": 200000.0,
        "duration_days": 30,
        "features": {
          "ai_limit": 150,
          "crawl_limit": 50
        },
        "ai_limit": 150,
        "crawl_limit": 50,
        "created_at": "2025-11-08T02:00:00Z",
        "updated_at": "2025-11-08T02:00:00Z"
      }
    },
    {
      "id": 9,
      "type": "subscription_plan",
      "attributes": {
        "id": 9,
        "name": "Gói Premium",
        "price": 300000.0,
        "duration_days": 30,
        "features": {
          "ai_limit": 300,
          "crawl_limit": 100
        },
        "ai_limit": 300,
        "crawl_limit": 100,
        "created_at": "2025-11-08T02:00:00Z",
        "updated_at": "2025-11-08T02:00:00Z"
      }
    }
  ]
}
```

**Lưu ý quan trọng:**
- ⚠️ **BẮT BUỘC**: Frontend phải gọi API này trước khi tạo payment
- ⚠️ **KHÔNG hardcode** `subscription_plan_id` - phải lấy từ API response
- Chỉ sử dụng `id` từ plans active (hiện tại: 7, 8, 9)
- Plans có thể thay đổi ID khi seed lại database

---

### 1. Tạo Payment Request

**Endpoint:** `POST /payments`

**Authentication:** Required (user token)

**Request Body:**
```json
{
  "payment": {
    "subscription_plan_id": 7,
    "payment_method": "senpay"
  }
}
```

**Lưu ý:**
- `subscription_plan_id` phải lấy từ API `/subscription-plans` (không hardcode)
- `payment_method` mặc định là "senpay" (có thể bỏ qua)

**Response (Success - 201):**
```json
{
  "data": {
    "id": 123,
    "amount": 100000,
    "payment_method": "senpay",
    "status": "pending",
    "checkout_url": "https://pay-sandbox.sepay.vn/v1/checkout/init",
    "form_data": {
      "merchant": "SP-TEST-TV899735",
      "order_amount": 100000,
      "order_invoice_number": "123",
      "order_description": "Subscription: Pro Plan",
      "return_url": "http://localhost:3000/payment/return",
      "ipn_url": "https://xxxx.ngrok.io/webhooks/senpay",
      "signature": "BASE64_ENCODED_SIGNATURE"
    },
    "expires_at": "2025-11-07T00:15:00Z",
    "subscription_plan": {
      "id": 1,
      "name": "Pro Plan",
      "price": 100000
    },
    "timestamps": {
      "created_at": "2025-11-06T23:00:00Z",
      "updated_at": "2025-11-06T23:00:00Z"
    }
  }
}
```

**Lưu ý quan trọng:**
- ✅ **Backend đã config tất cả** - BE đã tạo form_data với signature sẵn
- ✅ **Cần `checkout_url` và `form_data`** - Frontend cần tạo form và submit với form_data
- ✅ **Không cần tạo signature** - Backend đã tạo signature sẵn trong form_data
- `checkout_url` là URL SePay checkout endpoint
- `form_data` chứa tất cả params + signature (BE đã config sẵn)

**Response (Error - 422):**
```json
{
  "errors": [
    {
      "message": "Failed to create payment",
      "details": "Subscription plan is not active"
    }
  ]
}
```

**Các lỗi có thể gặp:**
- `"Subscription plan not found"` → `subscription_plan_id` không tồn tại
- `"Subscription plan is not active"` → Plan đã bị deactivate (thường do dùng ID cũ)
- `"User is required"` → Chưa authenticate

---

### 2. Kiểm tra Payment Status

**Endpoint:** `GET /payments/:id`

**Authentication:** Required (user token)

**Response (Success - 200):**
```json
{
  "data": {
    "id": 123,
    "amount": 100000,
    "payment_method": "senpay",
    "status": "success",
    "checkout_url": "https://pay-sandbox.sepay.vn/v1/checkout/init",
    "form_data": {
      "merchant": "SP-TEST-TV899735",
      "order_amount": 100000,
      "order_invoice_number": "123",
      "order_description": "Subscription: Pro Plan",
      "return_url": "http://localhost:3000/payment/return",
      "ipn_url": "https://xxxx.ngrok.io/webhooks/senpay",
      "signature": "BASE64_ENCODED_SIGNATURE"
    },
    "expires_at": null,
    "subscription_plan": {
      "id": 1,
      "name": "Pro Plan",
      "price": 100000
    },
    "timestamps": {
      "created_at": "2025-11-06T23:00:00Z",
      "updated_at": "2025-11-06T23:05:00Z"
    }
  }
}
```

**Payment Status:**
- `pending`: Đang chờ thanh toán
- `success`: Thanh toán thành công
- `failed`: Thanh toán thất bại
- `expired`: Hết hạn thanh toán (15 phút)
- `cancelled`: Đã hủy

---

## Frontend Implementation

### Step 0: Lấy danh sách Subscription Plans (BẮT BUỘC)

```javascript
// Example: React/Next.js
async function fetchSubscriptionPlans() {
  try {
    const response = await fetch('/subscription-plans', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error('Failed to fetch subscription plans');
    }

    const data = await response.json();
    // data.data là array các plans
    return data.data.map(plan => ({
      id: plan.attributes.id,
      name: plan.attributes.name,
      price: plan.attributes.price,
      durationDays: plan.attributes.duration_days,
      aiLimit: plan.attributes.ai_limit,
      crawlLimit: plan.attributes.crawl_limit
    }));
  } catch (error) {
    console.error('Error fetching subscription plans:', error);
    throw error;
  }
}
```

**Lưu ý:**
- Gọi API này khi component mount (useEffect)
- Lưu danh sách plans vào state
- Hiển thị cho user chọn plan
- **KHÔNG hardcode** subscription_plan_id

---

### Step 1: Tạo Payment Request

```javascript
// Example: React/Next.js
async function createPayment(subscriptionPlanId) {
  // ⚠️ subscriptionPlanId phải lấy từ API /subscription-plans
  // ⚠️ KHÔNG hardcode ID (ví dụ: không dùng 1, 2, 3)

  try {
    const response = await fetch('/payments', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}` // hoặc cookie-based auth
      },
      body: JSON.stringify({
        payment: {
          subscription_plan_id: subscriptionPlanId, // Lấy từ API /subscription-plans
          payment_method: 'senpay' // Optional, mặc định là "senpay"
        }
      })
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.errors[0].message);
    }

    const data = await response.json();
    return data.data; // { id, checkout_url, form_data, ... }
  } catch (error) {
    console.error('Payment creation failed:', error);
    throw error;
  }
}
```

---

### Step 2: Submit Form đến SenPay

Sau khi có `checkout_url` và `form_data` từ backend, Frontend **BẮT BUỘC** phải tạo form và submit với POST method.

**⚠️ LƯU Ý QUAN TRỌNG:**
- **KHÔNG được redirect trực tiếp** đến `checkout_url` (sẽ bị 404 vì endpoint chỉ chấp nhận POST)
- **PHẢI tạo form và submit** với POST method và form_data
- **KHÔNG dùng** `window.location.href` hoặc `router.push(checkout_url)`

**Cách 1: Tạo form và auto-submit (Recommended)**

```javascript
function submitToSenPay(paymentData) {
  const { checkout_url, form_data } = paymentData;

  if (!checkout_url || !form_data) {
    throw new Error('Checkout URL or form data is missing');
  }

  // Tạo form element
  const form = document.createElement('form');
  form.method = 'POST';
  form.action = checkout_url;
  form.style.display = 'none';

  // Thêm các hidden fields từ form_data (BE đã config sẵn)
  Object.keys(form_data).forEach(key => {
    const input = document.createElement('input');
    input.type = 'hidden';
    input.name = key;
    input.value = form_data[key];
    form.appendChild(input);
  });

  // Append form vào body và submit
  document.body.appendChild(form);
  form.submit();
}
```

**Cách 2: Sử dụng React/Next.js với form component**

```jsx
// React component
function SenPayCheckout({ paymentData }) {
  const { checkout_url, form_data } = paymentData;

  useEffect(() => {
    if (checkout_url && form_data) {
      const form = document.createElement('form');
      form.method = 'POST';
      form.action = checkout_url;
      form.style.display = 'none';

      Object.keys(form_data).forEach(key => {
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = key;
        input.value = form_data[key];
        form.appendChild(input);
      });

      document.body.appendChild(form);
      form.submit();
    }
  }, [checkout_url, form_data]);

  return (
    <div>
      <p>Đang chuyển hướng đến trang thanh toán...</p>
    </div>
  );
}
```

**Cách 3: Sử dụng JSX form (nếu muốn hiển thị form)**

```jsx
// React component
function SenPayCheckout({ paymentData }) {
  const { checkout_url, form_data } = paymentData;

  return (
    <form method="POST" action={checkout_url}>
      {Object.keys(form_data).map(key => (
        <input
          key={key}
          type="hidden"
          name={key}
          value={form_data[key]}
        />
      ))}
      <button type="submit">Thanh toán với SenPay</button>
    </form>
  );
}
```

**Lưu ý quan trọng:**
- ✅ **Backend đã config tất cả** - BE đã tạo form_data với signature sẵn
- ✅ **Chỉ cần submit form** - Frontend chỉ cần tạo form và submit với form_data
- ✅ **Không cần tạo signature** - Backend đã tạo signature sẵn trong form_data
- ⚠️ **BẮT BUỘC submit form với POST** - KHÔNG được redirect trực tiếp đến checkout_url (sẽ bị 404)
- ⚠️ **KHÔNG dùng `window.location.href`** - Phải tạo form và submit với POST method
- `checkout_url` là URL SePay checkout endpoint (chỉ chấp nhận POST request)
- `form_data` chứa tất cả params + signature (BE đã config sẵn, FE không cần sửa gì)

**❌ SAI - KHÔNG DÙNG:**
```javascript
// ❌ SAI - Sẽ bị 404 vì endpoint chỉ chấp nhận POST
window.location.href = checkout_url;
```

**✅ ĐÚNG - PHẢI DÙNG:**
```javascript
// ✅ ĐÚNG - Submit form với POST method
const form = document.createElement('form');
form.method = 'POST';
form.action = checkout_url;
// ... thêm form_data fields
form.submit();
```

---

### Step 3: Xử lý Redirect sau khi thanh toán

Sau khi user thanh toán trên SenPay, SenPay sẽ redirect user về `return_url` (đã config trong `.env.development`).

**Redirect URL:** `http://localhost:3000/payment/return`

**Query Params từ SenPay:**
- SenPay có thể redirect với query params như `order_invoice_number`, `status`, etc.
- Frontend cần parse query params và hiển thị kết quả

**Example:**
```javascript
// pages/payment/return.js (Next.js) hoặc route handler
function PaymentReturnPage() {
  const router = useRouter();
  const { order_invoice_number, status } = router.query;

  useEffect(() => {
    if (order_invoice_number) {
      // Kiểm tra payment status từ backend
      checkPaymentStatus(order_invoice_number);
    }
  }, [order_invoice_number]);

  async function checkPaymentStatus(paymentId) {
    try {
      const response = await fetch(`/payments/${paymentId}`, {
        headers: {
          'Authorization': `Bearer ${userToken}`
        }
      });

      if (!response.ok) {
        throw new Error('Failed to fetch payment status');
      }

      const data = await response.json();
      const payment = data.data;

      if (payment.status === 'success') {
        // Hiển thị success message
        showSuccessMessage('Thanh toán thành công!');
        // Redirect về dashboard hoặc subscription page
        router.push('/dashboard');
      } else if (payment.status === 'failed') {
        // Hiển thị error message
        showErrorMessage('Thanh toán thất bại. Vui lòng thử lại.');
      } else if (payment.status === 'pending') {
        // Vẫn đang pending, có thể poll status
        pollPaymentStatus(paymentId);
      }
    } catch (error) {
      console.error('Failed to check payment status:', error);
      showErrorMessage('Không thể kiểm tra trạng thái thanh toán.');
    }
  }

  function pollPaymentStatus(paymentId) {
    // Poll payment status mỗi 3 giây
    const interval = setInterval(async () => {
      const response = await fetch(`/payments/${paymentId}`, {
        headers: {
          'Authorization': `Bearer ${userToken}`
        }
      });

      if (response.ok) {
        const data = await response.json();
        const payment = data.data;

        if (payment.status !== 'pending') {
          clearInterval(interval);
          if (payment.status === 'success') {
            showSuccessMessage('Thanh toán thành công!');
            router.push('/dashboard');
          } else {
            showErrorMessage('Thanh toán thất bại.');
          }
        }
      }
    }, 3000);

    // Stop polling sau 5 phút
    setTimeout(() => {
      clearInterval(interval);
    }, 5 * 60 * 1000);
  }

  return (
    <div>
      <h1>Đang xử lý thanh toán...</h1>
      <p>Vui lòng đợi trong giây lát.</p>
    </div>
  );
}
```

---

## Error Handling

### 0. Common Errors

**Lỗi 404 khi redirect đến checkout_url:**

**Nguyên nhân:** FE đang redirect trực tiếp đến `checkout_url` thay vì submit form với POST method.

**Giải pháp:**
```javascript
// ❌ SAI - Sẽ bị 404
window.location.href = payment.checkout_url;

// ✅ ĐÚNG - Submit form với POST
function submitToSenPay(paymentData) {
  const { checkout_url, form_data } = paymentData;

  const form = document.createElement('form');
  form.method = 'POST';  // ⚠️ BẮT BUỘC phải là POST
  form.action = checkout_url;
  form.style.display = 'none';

  Object.keys(form_data).forEach(key => {
    const input = document.createElement('input');
    input.type = 'hidden';
    input.name = key;
    input.value = form_data[key];
    form.appendChild(input);
  });

  document.body.appendChild(form);
  form.submit();
}
```

**Lưu ý:** Endpoint `/v1/checkout/init` chỉ chấp nhận POST request, không chấp nhận GET request.

**Lỗi 403 khi submit form:**

**Nguyên nhân có thể:**
1. **Ngrok URL đã expire** - ngrok free có thể expire sau một thời gian
2. **Ngrok URL không đúng format** - cần đảm bảo URL đúng format
3. **Signature format không đúng** - cần kiểm tra lại SePay docs
4. **`return_url` hoặc `ipn_url` phải là HTTPS** - không phải HTTP localhost
5. **Cloudflare chặn request từ localhost** - cần test với domain thật hoặc ngrok

**Giải pháp:**

1. **Kiểm tra ngrok URL có còn hoạt động không:**
   ```bash
   # Test ngrok URL
   curl https://xxxx.ngrok.io/payment/return
   # Nếu bị 404 hoặc connection refused → ngrok đã expire
   ```

2. **Kiểm tra `return_url` và `ipn_url` trong logs backend:**
   ```ruby
   # Backend logs sẽ show:
   # SenPay URLs - redirect_url: https://xxxx.ngrok.io/payment/return, webhook_url: https://xxxx.ngrok.io/webhooks/senpay
   ```
   - Nếu URL là `http://localhost` → cần đổi sang HTTPS ngrok
   - Nếu URL là ngrok nhưng bị 403 → có thể ngrok đã expire

3. **Kiểm tra signature trong logs backend:**
   ```ruby
   # Backend logs sẽ show:
   # SenPay signature string: ipn_url=...&merchant=...&order_amount=...&order_description=...&order_invoice_number=...&return_url=...
   # SenPay signature: BASE64_ENCODED_SIGNATURE
   ```
   - Verify signature string có đúng format không
   - Verify signature có đúng không

4. **Restart ngrok và update URLs:**
   ```bash
   # Stop ngrok cũ
   # Start ngrok mới
   ngrok http 4000  # Port của BE

   # Update .env với ngrok URL mới
   SENPAY_REDIRECT_URL=https://xxxx.ngrok-free.app/payment/return
   SENPAY_WEBHOOK_URL=https://xxxx.ngrok-free.app/webhooks/senpay
   ```

5. **Kiểm tra ngrok có bị Cloudflare chặn không:**
   - Ngrok free có thể bị Cloudflare chặn
   - Thử dùng ngrok paid hoặc domain thật

6. **Liên hệ SePay support** - nếu vẫn bị 403, có thể cần whitelist IP hoặc domain

### 1. Payment Creation Errors

```javascript
try {
  const payment = await createPayment(subscriptionPlanId);
  submitToSenPay(payment);
} catch (error) {
  if (error.message.includes('Subscription plan not found')) {
    showErrorMessage('Gói subscription không tồn tại.');
  } else if (error.message.includes('Subscription plan is not active')) {
    showErrorMessage('Gói subscription không khả dụng.');
  } else {
    showErrorMessage('Không thể tạo payment. Vui lòng thử lại.');
  }
}
```

### 2. Payment Timeout

Payment sẽ expire sau 15 phút. Frontend nên:
- Hiển thị countdown timer
- Disable payment button nếu expired
- Hiển thị message khi expired

```javascript
function PaymentTimer({ expiresAt }) {
  const [timeLeft, setTimeLeft] = useState(null);

  useEffect(() => {
    const interval = setInterval(() => {
      const now = new Date();
      const expires = new Date(expiresAt);
      const diff = expires - now;

      if (diff <= 0) {
        setTimeLeft('Hết hạn');
        clearInterval(interval);
      } else {
        const minutes = Math.floor(diff / 60000);
        const seconds = Math.floor((diff % 60000) / 1000);
        setTimeLeft(`${minutes}:${seconds.toString().padStart(2, '0')}`);
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [expiresAt]);

  return (
    <div>
      <p>Thời gian còn lại: {timeLeft}</p>
    </div>
  );
}
```

---

## Best Practices

### 1. Loading States

```javascript
const [isLoading, setIsLoading] = useState(false);

async function handlePayment(subscriptionPlanId) {
  setIsLoading(true);
  try {
    const payment = await createPayment(subscriptionPlanId);
    submitToSenPay(payment);
  } catch (error) {
    showErrorMessage(error.message);
    setIsLoading(false);
  }
}
```

### 2. Payment Status Polling

Nếu SenPay redirect về nhưng webhook chưa được xử lý, Frontend nên poll payment status:

```javascript
async function pollPaymentStatus(paymentId, maxAttempts = 20) {
  for (let i = 0; i < maxAttempts; i++) {
    await new Promise(resolve => setTimeout(resolve, 3000)); // Wait 3 seconds

    const response = await fetch(`/payments/${paymentId}`, {
      headers: {
        'Authorization': `Bearer ${userToken}`
      }
    });

    if (response.ok) {
      const data = await response.json();
      const payment = data.data;

      if (payment.status !== 'pending') {
        return payment;
      }
    }
  }

  throw new Error('Payment status check timeout');
}
```

### 3. User Experience

- Hiển thị loading spinner khi tạo payment
- Hiển thị countdown timer cho payment expiration
- Hiển thị clear success/error messages
- Redirect user về dashboard sau khi thanh toán thành công
- Allow user retry payment nếu failed

---

## Testing

### 1. Test Payment Creation

```javascript
// Test với subscription plan ID = 1
const payment = await createPayment(1);
console.log('Payment created:', payment);
console.log('Checkout URL:', payment.checkout_url);
console.log('Form Data:', payment.form_data);

// Verify checkout_url và form_data có tồn tại
if (!payment.checkout_url || !payment.form_data) {
  console.error('Missing checkout_url or form_data');
} else {
  console.log('✅ Checkout URL and form data are valid');
}
```

### 2. Test Form Submission

```javascript
// Verify checkout_url và form_data có tồn tại
const payment = await createPayment(1);
if (!payment.checkout_url || !payment.form_data) {
  console.error('Missing checkout_url or form_data');
} else {
  console.log('Checkout URL:', payment.checkout_url);
  console.log('Form Data:', payment.form_data);
  // Submit form với form_data
  submitToSenPay(payment);
}
```

### 3. Test Redirect Handling

- Test với payment success
- Test với payment failed
- Test với payment pending (polling)
- Test với payment expired

---

## Summary

1. **Tạo Payment:** Gọi `POST /payments` với `subscription_plan_id` → Backend:
   - Tạo payment record
   - Tạo form_data với signature (BE config tất cả)
   - Trả về checkout_url + form_data cho Frontend
2. **Submit Form:** Tạo form và submit với form_data (BE đã config sẵn)
3. **Handle Redirect:** Parse query params từ SenPay redirect và check payment status
4. **Poll Status:** Nếu payment vẫn pending, poll status mỗi 3 giây
5. **Show Result:** Hiển thị success/error message và redirect user

**Lưu ý:** Backend đã xử lý tất cả logic phức tạp (signature generation, form data creation), Frontend chỉ cần submit form.

---

## API Reference

### POST /payments
- **Auth:** Required
- **Body:** `{ payment: { subscription_plan_id, payment_method } }`
- **Response:** Payment object với `checkout_url` và `form_data` (Backend đã config tất cả)

### GET /payments/:id
- **Auth:** Required
- **Response:** Payment object với current status

---

## Support

Nếu có vấn đề, kiểm tra:
1. Payment status từ backend API
2. SenPay webhook logs
3. Browser console errors
4. Network requests trong DevTools

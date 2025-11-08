# Frontend SenPay Integration Guide

## Tổng quan

Hướng dẫn tích hợp SenPay payment gateway vào Frontend application. Frontend cần tạo payment request, submit form đến SenPay, và xử lý redirect sau khi thanh toán.

---

## Payment Flow

```
1. User chọn subscription plan
2. Frontend gọi API tạo payment → Backend trả về form_data + checkout_url
3. Frontend tạo HTML form và submit đến SenPay checkout_url
4. User thanh toán trên SenPay
5. SenPay redirect user về redirect_url (frontend)
6. SenPay gửi webhook đến backend (tự động)
7. Frontend hiển thị kết quả thanh toán
```

---

## API Endpoints

### 1. Tạo Payment Request

**Endpoint:** `POST /payments`

**Authentication:** Required (user token)

**Request Body:**
```json
{
  "payment": {
    "subscription_plan_id": 1,
    "payment_method": "senpay"
  }
}
```

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

**Response (Error - 422):**
```json
{
  "errors": [
    {
      "message": "Failed to create payment",
      "details": "Subscription plan not found"
    }
  ]
}
```

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
    "form_data": { ... },
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

### Step 1: Tạo Payment Request

```javascript
// Example: React/Next.js
async function createPayment(subscriptionPlanId) {
  try {
    const response = await fetch('/payments', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}` // hoặc cookie-based auth
      },
      body: JSON.stringify({
        payment: {
          subscription_plan_id: subscriptionPlanId,
          payment_method: 'senpay'
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

Sau khi có `checkout_url` và `form_data`, Frontend cần tạo HTML form và submit đến SenPay.

**Cách 1: Tạo form và auto-submit (Recommended)**

```javascript
function submitToSenPay(paymentData) {
  const { checkout_url, form_data } = paymentData;

  // Tạo form element
  const form = document.createElement('form');
  form.method = 'POST';
  form.action = checkout_url;
  form.style.display = 'none';

  // Thêm các hidden fields từ form_data
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

**Cách 2: Redirect với query params (Không recommended - SenPay yêu cầu POST)**

```javascript
// ❌ KHÔNG DÙNG CÁCH NÀY - SenPay yêu cầu POST request
function redirectToSenPay(paymentData) {
  const { checkout_url, form_data } = paymentData;
  const params = new URLSearchParams(form_data);
  window.location.href = `${checkout_url}?${params.toString()}`;
}
```

**Cách 3: Sử dụng React/Next.js với form component**

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
  } finally {
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

    const response = await fetch(`/api/payments/${paymentId}`, {
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
```

### 2. Test Form Submission

```javascript
// Verify form data có đầy đủ fields
const requiredFields = ['merchant', 'order_amount', 'order_invoice_number', 'signature'];
const formData = payment.form_data;

requiredFields.forEach(field => {
  if (!formData[field]) {
    console.error(`Missing required field: ${field}`);
  }
});
```

### 3. Test Redirect Handling

- Test với payment success
- Test với payment failed
- Test với payment pending (polling)
- Test với payment expired

---

## Summary

1. **Tạo Payment:** Gọi `POST /payments` với `subscription_plan_id`
2. **Submit Form:** Tạo HTML form với `form_data` và submit đến `checkout_url`
3. **Handle Redirect:** Parse query params từ SenPay redirect và check payment status
4. **Poll Status:** Nếu payment vẫn pending, poll status mỗi 3 giây
5. **Show Result:** Hiển thị success/error message và redirect user

---

## API Reference

### POST /payments
- **Auth:** Required
- **Body:** `{ payment: { subscription_plan_id, payment_method } }`
- **Response:** Payment object với `checkout_url` và `form_data`

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

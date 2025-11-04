# Frontend API - Google OAuth Authentication

## 🔗 Base URL

**⚠️ Phải khai báo qua ENV variable:**

```bash
# .env
NUXT_PUBLIC_BACKEND_URL=http://localhost:4000  # development
# hoặc
NUXT_PUBLIC_BACKEND_URL=https://api.yourdomain.com  # production
```

**Đọc trong code (Nuxt.js):**
```javascript
const backendUrl = useRuntimeConfig().public.backendUrl;
// hoặc
const backendUrl = process.env.NUXT_PUBLIC_BACKEND_URL;
```

---

## 🔐 Authentication Endpoints

### 1. Login (Initiate OAuth)

**Endpoint:**
```
GET /oauth/google/redirect?return_url=<FRONTEND_URL>
```

**Parameters:**
- `return_url` (optional): URL FE muốn redirect về sau khi login xong

**Cách dùng:**
```javascript
const config = useRuntimeConfig();
const returnUrl = window.location.href;
window.location.href = `${config.public.backendUrl}/oauth/google/redirect?return_url=${encodeURIComponent(returnUrl)}`;
```

**Response:**
- `302` redirect → Google OAuth page

---

### 2. Get Current User

**Endpoint:**
```
GET /users/me
```

**Yêu cầu:**
- Phải có session cookie (tự động gửi sau login)
- Request **phải có** `credentials: 'include'`

**Cách dùng:**
```javascript
const config = useRuntimeConfig();
const response = await fetch(`${config.public.backendUrl}/users/me`, {
  credentials: 'include'  // ⚠️ REQUIRED
});
```

**Response Success (200):**
```json
{
  "data": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "subscription_plan_id": 1
  }
}
```

**Response Error (401):**
```json
{
  "errors": [
    {
      "message": "Unauthorized",
      "details": "Not authenticated"
    }
  ]
}
```

**Xử lý:**
- Nếu `response.status === 401` → Redirect về login
- Nếu `response.ok` → Lấy `data.data` để dùng

---

## ⚠️ Important Notes

1. **Backend URL:** Phải dùng ENV variable `NUXT_PUBLIC_BACKEND_URL`, không hardcode
2. **Credentials:** Mọi request **phải có** `credentials: 'include'` (fetch) hoặc `withCredentials: true` (axios)
3. **Session Cookie:** Backend tự động tạo sau login, browser tự động gửi (không cần xử lý)
4. **Session Lifetime:** 1 giờ, sau đó cần login lại
5. **401 Handling:** Tự động redirect về login

---

## 🔄 Flow

```
1. User click login → Redirect đến /oauth/google/redirect?return_url=...
2. User authenticate trên Google
3. Backend redirect về FE với session cookie
4. FE gọi /users/me để check auth
5. Nếu 401 → Redirect về login, nếu 200 → Lấy user data
```

---

## ✅ Checklist

- [ ] Setup ENV variable `NUXT_PUBLIC_BACKEND_URL` trong file `.env`
- [ ] Implement redirect đến `/oauth/google/redirect`
- [ ] Implement gọi `/users/me` với `credentials: 'include'`
- [ ] Xử lý 401 → Redirect về login

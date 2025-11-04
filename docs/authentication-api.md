# Authentication API Documentation

## Overview
Authentication sử dụng Google OAuth 2.0 với session-based authentication. Sau khi authenticate thành công, server sẽ lưu `user_id` vào session cookie. Tất cả các protected endpoints sẽ tự động check session để authenticate.

## Authentication Flow

### Step 1: Redirect user to Google OAuth

**FE action:** Redirect user đến backend endpoint để bắt đầu OAuth flow.

```
GET /oauth/google/redirect?return_url=<FRONTEND_URL>
```

**Parameters:**
- `return_url` (optional): URL FE muốn user được redirect về sau khi authenticate thành công
  - Nếu không có, sẽ redirect về URL gọi API này (referer)

**Example:**
```javascript
// Redirect user đến BE để bắt đầu OAuth
window.location.href = 'https://api.yourdomain.com/oauth/google/redirect?return_url=https://app.yourdomain.com/dashboard';
```

**Response:**
- Status: `302 Found`
- Location: Google OAuth consent screen URL
- **Note:** User sẽ được redirect đến Google OAuth page (không có JSON response)

---

### Step 2: User authenticate trên Google

User sẽ thấy Google OAuth consent screen:
- Select Google account
- Grant permissions
- Google sẽ redirect về backend callback endpoint

**FE không cần làm gì ở step này** - Google tự động xử lý.

---

### Step 3: Backend callback & redirect về FE

Google redirect về:
```
GET /oauth/google/callback?code=<AUTHORIZATION_CODE>&state=<STATE>
```

**BE sẽ:**
1. Exchange code lấy access_token từ Google
2. Get user info từ Google (email, name)
3. Create/find user trong database
4. Lưu `user_id` vào session cookie
5. Redirect về `return_url` từ step 1 (hoặc render success message)

**Response:**
- Status: `302 Found`
- Location: `return_url` (từ step 1)
- **Set-Cookie:** Session cookie với user_id

**Example response headers:**
```
HTTP/1.1 302 Found
Location: https://app.yourdomain.com/dashboard
Set-Cookie: _dtu_support_session=abc123...; Path=/; HttpOnly; Secure; SameSite=Lax
```

---

### Step 4: FE nhận session cookie và call protected APIs

Sau khi user được redirect về FE (step 3), browser đã có session cookie. FE có thể gọi các protected APIs.

**Important:** 
- Session cookie được set tự động bởi browser (không cần FE xử lý)
- Cookie được gửi tự động trong mọi request đến backend
- Cookie có `HttpOnly` flag (không thể access từ JavaScript)

---

## Protected Endpoints

Tất cả protected endpoints cần session cookie. Nếu không có hoặc expired, sẽ trả về `401 Unauthorized`.

### Get Current User

```
GET /users/me
```

**Headers:**
- `Cookie: _dtu_support_session=...` (tự động gửi bởi browser)

**Response (Success):**
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

**Response (Unauthorized - 401):**
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

**Example:**
```javascript
// Fetch current user (cookie tự động gửi)
const response = await fetch('https://api.yourdomain.com/users/me', {
  credentials: 'include' // Important: include cookies
});

if (response.ok) {
  const data = await response.json();
  console.log('Current user:', data.data);
} else if (response.status === 401) {
  // Not authenticated - redirect to login
  window.location.href = '/login';
}
```

---

### Get User by ID

```
GET /users/:id
```

**Parameters:**
- `:id` - User ID (integer) hoặc `"me"` để lấy current user

**Headers:**
- `Cookie: _dtu_support_session=...` (tự động gửi bởi browser)

**Response (Success):**
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

**Example:**
```javascript
// Get user by ID
const response = await fetch('https://api.yourdomain.com/users/1', {
  credentials: 'include'
});

const data = await response.json();
console.log('User:', data.data);
```

---

## Error Responses

### 401 Unauthorized
User chưa authenticate hoặc session expired.

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

**FE action:** Redirect user đến `/oauth/google/redirect` để login lại.

---

### 400 Bad Request
Invalid request parameters hoặc OAuth flow failed.

```json
{
  "errors": [
    {
      "message": "Invalid OAuth callback",
      "details": "Missing code or state parameter"
    }
  ]
}
```

---

## Session Management

### Session Lifetime
- Session cache: **1 hour**
- Sau 1 hour, session tự động expired
- User cần login lại nếu session expired

### Logout
Hiện tại chưa có logout endpoint. FE có thể:
1. Clear session cookie (nếu có thể)
2. Redirect user đến `/oauth/google/redirect` để login lại (Google sẽ prompt login)

---

## Complete FE Integration Example

```javascript
// 1. Login function
function login() {
  const returnUrl = `${window.location.origin}/dashboard`;
  window.location.href = `https://api.yourdomain.com/oauth/google/redirect?return_url=${encodeURIComponent(returnUrl)}`;
}

// 2. Check authentication & get current user
async function getCurrentUser() {
  try {
    const response = await fetch('https://api.yourdomain.com/users/me', {
      credentials: 'include'
    });

    if (response.status === 401) {
      // Not authenticated
      return null;
    }

    const data = await response.json();
    return data.data;
  } catch (error) {
    console.error('Failed to get current user:', error);
    return null;
  }
}

// 3. Protected API call wrapper
async function protectedApiCall(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    credentials: 'include'
  });

  if (response.status === 401) {
    // Session expired - redirect to login
    login();
    throw new Error('Unauthorized');
  }

  return response;
}

// 4. Usage
async function loadUserDashboard() {
  const user = await getCurrentUser();
  
  if (!user) {
    login();
    return;
  }

  console.log('User logged in:', user);
  // Continue with authenticated requests...
}
```

---

## API Base URLs

**Development:**
```
http://localhost:3000
```

**Production:**
```
https://api.yourdomain.com
```

---

## Notes

1. **CORS:** FE cần được whitelist trong CORS config (xem `config/initializers/cors.rb`)
2. **Credentials:** Luôn dùng `credentials: 'include'` khi call API từ FE
3. **SameSite Cookie:** Cookie có `SameSite=Lax` - chỉ gửi trong same-site requests hoặc top-level navigation
4. **HttpOnly:** Session cookie không thể access từ JavaScript (bảo mật)
5. **Secure:** Cookie chỉ gửi qua HTTPS (production)

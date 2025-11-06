# Chat API Response Format

## 📋 Tổng Quan

Khi client gọi `POST /api/chat`, backend sẽ trả về response theo format chuẩn từ `Renderable` concern.

## 🔄 Flow Hoàn Chỉnh

```
1. Client → POST /api/chat { messages: [...] } với query: /api/chat?tone=...
2. ChatsController → Chats::ProcessMessageService.call(messages:, tone:)
3. Service → Gọi Gemini API với tools definition
4. Nếu có function_call → Execute tool → Gửi tool_result về Gemini → Nhận final response
5. Service → Trả về { success, content, tool_result, metadata } (tool_result có thể kèm uiHtml)
6. Controller → render_success(data: { content, toolResult, metadata })
7. Client ← JSON Response
```

## 📤 Response Format

### Success Response (có tool calling)

**Khi Gemini gọi function/tool:**

```json
{
  "data": {
    "content": "Dựa vào GPA hiện tại 3.0 và số tín chỉ còn lại 60, nếu đạt toàn điểm A, bạn sẽ đạt GPA 3.52, đủ để đạt loại Giỏi.",
    "toolResult": {
      "toolName": "calculateTargetGpa",
      "data": {
        "maxGpaWithAllA": 3.520,
        "canReachTarget": true,
        "graduationClassification": {
          "rank": "good",
          "minGpa": 3.20,
          "maxGpa": 3.59
        }
      },
      "uiHtml": "<div class=\"rounded-lg border p-4 bg-white dark:bg-zinc-900\">...</div>"
    },
    "metadata": {
      "messageId": "msg-1720170000-1234",
      "timestamp": "2024-11-04T11:30:00Z",
      "intent": "calculation"
    }
  }
}
```

### Success Response (không có tool calling)

**Khi Gemini chỉ trả lời text, không gọi tool:**

```json
{
  "data": {
    "content": "Để tính GPA mục tiêu, tôi cần biết số tín chỉ đã học, GPA hiện tại, và số tín chỉ còn lại.",
    "metadata": {
      "messageId": "msg-1720170000-5678",
      "timestamp": "2024-11-04T11:31:00Z",
      "intent": "question"
    }
  }
}
```

**Lưu ý:** `toolResult` sẽ không có trong response (hoặc `null`) vì không có tool calling.

### Error Response

**Khi có lỗi:**

```json
{
  "errors": [
    {
      "message": "Failed to process message",
      "details": "GEMINI_API_KEY is required"
    }
  ]
}
```

## 🔍 Chi Tiết Các Trường

### `content` (string, required)
- Text response từ Gemini
- Luôn có trong success response
- Ví dụ: "Dựa vào GPA hiện tại 3.0..."

### `toolResult` (object, optional)
- Chỉ có khi Gemini gọi function/tool
- Cấu trúc:
  - `toolName` (string): Tên tool được gọi
  - `data` (object): Kết quả từ tool execution
  - `uiHtml` (string, optional): HTML Tailwind đã render sẵn; FE render trực tiếp nếu có

### `metadata` (object, required)
- Thông tin metadata
- `messageId`: ID duy nhất của message
- `timestamp`: ISO 8601 timestamp
- `intent`: Loại intent ("calculation" | "question")

## 📊 Tool Result Data Structure

### Tool: `calculateTargetGpa`

```json
{
  "toolName": "calculateTargetGpa",
  "data": {
    "maxGpaWithAllA": 3.520,
    "canReachTarget": true,
    "graduationClassification": {
      "rank": "good",
      "minGpa": 3.20,
      "maxGpa": 3.59
    }
  },
  "uiHtml": "<div class=\"rounded-lg border p-4 bg-white dark:bg-zinc-900\">...Tailwind content...</div>"
}
```

### Tool: `calculateSimulationGpa`

```json
{
  "toolName": "calculateSimulationGpa",
  "data": {
    "finalGpa": 3.029,
    "remainingGpa": 3.057,
    "totalCredits": 120,
    "graduationClassification": {
      "rank": "fair",
      "minGpa": 2.50,
      "maxGpa": 3.19
    },
    "distributionSummary": "5 tín A+, 10 tín A, 5 tín A−, 10 tín B+, 10 tín B, 5 tín B−, 5 tín C+, 5 tín C, 3 tín C−, 2 tín D",
    "isWeakResult": false
  },
  "uiHtml": "<div class=\"rounded-lg border p-4 bg-white dark:bg-zinc-900\">...Tailwind content...</div>"
}
```

### Tool: `calculatePeGpa`

```json
{
  "toolName": "calculatePeGpa",
  "data": {
    "average": 8.0,
    "isPass": true,
    "inputs": {
      "pe1": 8.0,
      "pe2": 7.0,
      "pe3": 9.0
    }
  },
  "uiHtml": "<div class=\"rounded-lg border p-4 bg-white dark:bg-zinc-900\">...Tailwind content...</div>"
}
```

### Tool: `calculateRequiredFinalScore`

**Mục đích:** Tính điểm thi cuối kỳ tối thiểu cần đạt để qua môn.

**Response:**

```json
{
  "toolName": "calculateRequiredFinalScore",
  "data": {
    "requiredFinalScore": 1.43,
    "canPass": true,
    "formula": "Điểm thi cần = (Điểm tối thiểu - Điểm hiện tại) / Trọng số cuối kỳ",
    "partialScore": 3.9,
    "finalExamWeight": 50.0,
    "minPassingScore": 4.0
  },
  "uiHtml": "<div class=\"rounded-lg border p-4 bg-white dark:bg-zinc-900\">...Tailwind content...</div>"
}
```

**Chi tiết các trường:**
- `requiredFinalScore` (number | null): Điểm thi cuối kỳ tối thiểu cần đạt (thang 10). `null` nếu không thể qua môn.
- `canPass` (boolean): `true` nếu có thể qua môn, `false` nếu không thể (ngay cả khi đạt 10.0).
- `formula` (string): Công thức tính điểm thi cần.
- `partialScore` (number): Tổng điểm phần đã có từ các thành phần (thang 10, làm tròn 2 chữ số).
- `finalExamWeight` (number): Trọng số thi cuối kỳ (%).
- `minPassingScore` (number): Điểm tối thiểu để qua môn (thang 10, thường là 4.0).

**Lưu ý:** `requiredFinalScore` tối thiểu là 1.0 (theo quy định trường).

### Tool: `calculateFinalScore`

**Mục đích:** Tính điểm tổng kết và xếp loại khi biết điểm thi cuối kỳ (dự đoán điểm tổng kết).

**Response:**

```json
{
  "toolName": "calculateFinalScore",
  "data": {
    "finalScore": 7.9,
    "finalScoreGpa": 3.33,
    "letterGrade": "B+",
    "isPass": true,
    "partialScore": 3.9,
    "finalExamScore": 8.0,
    "finalExamWeight": 50.0,
    "minPassingScore": 4.0
  },
  "uiComponent": "FinalScoreResultCard"
}
```

**Chi tiết các trường:**
- `finalScore` (number): Điểm tổng kết (thang 10, làm tròn 2 chữ số).
- `finalScoreGpa` (number): Điểm tổng kết quy đổi sang thang 4 (làm tròn 2 chữ số).
- `letterGrade` (string): Điểm chữ theo thang điểm Duy Tân: `"A+"`, `"A"`, `"A-"`, `"B+"`, `"B"`, `"B-"`, `"C+"`, `"C"`, `"C-"`, `"D"`, `"F"`.
- `isPass` (boolean): `true` nếu đạt môn (≥ `minPassingScore`), `false` nếu không đạt.
- `partialScore` (number): Tổng điểm phần đã có trước khi thi cuối kỳ (thang 10, làm tròn 2 chữ số).
- `finalExamScore` (number): Điểm thi cuối kỳ đã nhập (thang 10).
- `finalExamWeight` (number): Trọng số thi cuối kỳ (%).
- `minPassingScore` (number): Điểm tối thiểu để qua môn (thang 10, thường là 4.0).

**Bảng quy đổi điểm chữ (theo thang điểm Duy Tân):**
- `9.5 - 10.0` → `"A+"` (GPA 4.0)
- `8.5 - 9.4` → `"A"` (GPA 4.0)
- `8.0 - 8.4` → `"A-"` (GPA 3.65)
- `7.5 - 7.9` → `"B+"` (GPA 3.33)
- `7.0 - 7.4` → `"B"` (GPA 3.0)
- `6.5 - 6.9` → `"B-"` (GPA 2.65)
- `6.0 - 6.4` → `"C+"` (GPA 2.33)
- `5.5 - 5.9` → `"C"` (GPA 2.0)
- `4.5 - 5.4` → `"C-"` (GPA 1.65)
- `4.0 - 4.4` → `"D"` (GPA 1.0)
- `0.0 - 3.9` → `"F"` (GPA 0.0) - Không đạt

## 🎯 Cách Client Sử Dụng

### TypeScript Interface (Frontend)

```typescript
interface ChatResponse {
  data: {
    content: string
    toolResult?: {
      toolName: "calculateTargetGpa" | "calculateSimulationGpa" | "calculatePeGpa" | "calculateRequiredFinalScore" | "calculateFinalScore"
      data?: Record<string, unknown>
      uiHtml?: string
    }
    metadata: {
      messageId: string
      timestamp: string
      intent: "calculation" | "question"
    }
  }
}

interface ErrorResponse {
  errors: Array<{
    message: string
    details?: string
  }>
}

### Truyền tham số tone (tùy chọn, qua query params)

- Ý nghĩa: ghi đè giọng điệu hệ thống khi sinh câu trả lời. Nếu không truyền, backend dùng mặc định: "Thân thiện, chuyên nghiệp, súc tích".
- Giá trị gợi ý: "Trang trọng", "Thân thiện", "Ngắn gọn", "Giải thích chi tiết". Có thể kết hợp: "Thân thiện, súc tích".

Ví dụ truyền `tone` qua query params:

```bash
curl -X POST 'http://localhost:3000/api/chat?tone=Th%C3%A2n%20thi%E1%BB%87n%2C%20s%C3%BAc%20t%E1%BA%AFc' \
  -H 'Content-Type: application/json' \
  -d '{ "messages": [{ "role": "user", "content": "hi" }] }'
```

Ví dụ (fetch) dùng query params:

```typescript
await fetch('/api/chat?tone=Trang%20tr%E1%BB%8Dng%2C%20s%C3%BAc%20t%E1%BA%AFc', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    messages: [{ role: 'user', content: 'Tôi muốn tính GPA mục tiêu' }]
  })
})
```

Ghi chú:
- Backend đọc `tone` từ `params[:tone]` trong query string.
```

### Ví Dụ Sử Dụng (Frontend)

```typescript
const response = await fetch('/api/chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    messages: [
      { role: 'user', content: 'Tôi muốn tính GPA mục tiêu' }
    ]
  })
})

const data = await response.json()

if (data.data) {
  // Hiển thị text response
  console.log(data.data.content)

  // Nếu có toolResult.uiHtml → render trực tiếp
  if (data.data.toolResult?.uiHtml) {
    renderHtml(data.data.toolResult.uiHtml)
  }
} else if (data.errors) {
  // Xử lý lỗi
  console.error(data.errors[0].message)
}
```

## 📝 Lưu Ý

1. **`toolResult` là optional**: Chỉ có khi Gemini gọi function/tool
2. **`metadata` luôn có**: Trong mọi success response
3. **`content` luôn có**: Text response từ Gemini
4. **Error format**: Luôn là `{ errors: [...] }` khi có lỗi
5. **HTTP Status Codes**:
   - `200 OK`: Success
   - `400 Bad Request`: Missing parameter
   - `401 Unauthorized`: Not authenticated
   - `500 Internal Server Error`: Service error

## 🔗 Related Files

- `app/controllers/chats_controller.rb` - Controller endpoint
- `app/services/chats/process_message_service.rb` - Service xử lý logic
- `app/services/chats/tools_definition_service.rb` - Tools definition
- `app/controllers/concerns/renderable.rb` - Render format concern

# Chat API Response Format

## 📋 Tổng Quan

Khi client gọi `POST /api/chat`, backend sẽ trả về response theo format chuẩn từ `Renderable` concern.

## 🔄 Flow Hoàn Chỉnh

```
1. Client → POST /api/chat { messages: [...] }
2. ChatsController → Chats::ProcessMessageService.call(messages:)
3. Service → Gọi Gemini API với tools definition
4. Nếu có function_call → Execute tool → Gửi tool_result về Gemini → Nhận final response
5. Service → Trả về { success, content, tool_result, metadata }
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
      "uiComponent": "GpaResultCard"
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
    - `"calculateTargetGpa"`
    - `"calculateSimulationGpa"`
    - `"calculatePeGpa"`
  - `data` (object): Kết quả từ tool execution
  - `uiComponent` (string): Tên component FE nên render
    - `"GpaResultCard"` cho calculateTargetGpa, calculateSimulationGpa
    - `"PeResultCard"` cho calculatePeGpa

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
  "uiComponent": "GpaResultCard"
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
  "uiComponent": "GpaResultCard"
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
  "uiComponent": "PeResultCard"
}
```

## 🎯 Cách Client Sử Dụng

### TypeScript Interface (Frontend)

```typescript
interface ChatResponse {
  data: {
    content: string
    toolResult?: {
      toolName: "calculateTargetGpa" | "calculateSimulationGpa" | "calculatePeGpa"
      data: Record<string, unknown>
      uiComponent: "GpaResultCard" | "PeResultCard"
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

  // Nếu có toolResult, render rich UI component
  if (data.data.toolResult) {
    const { toolName, data: toolData, uiComponent } = data.data.toolResult

    // Render component tương ứng
    if (uiComponent === 'GpaResultCard') {
      renderGpaResultCard(toolData)
    } else if (uiComponent === 'PeResultCard') {
      renderPeResultCard(toolData)
    }
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

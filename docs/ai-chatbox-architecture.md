# 🤖 Chatbox AI - Tư vấn Điểm Học Viên

## 🎯 Mục tiêu tổng thể

Xây chatbot AI có thể:

1. **Nói chuyện tự nhiên**: Gemini điều hướng hội thoại, không cần hardcode flow
2. **Tự hỏi – tự thu thập đủ thông tin** → gọi hàm tính điểm (function calling/tool)
3. **Trả lời câu hỏi lý thuyết**:
   - Nếu gặp câu hỏi như "quy đổi điểm", "công thức trường", "quy chế thi lại"
   - → Tìm câu trả lời chính xác từ tài liệu trường bằng Vector DB (RAG)
4. **Logic thông minh**: Gemini tự chọn flow (tool calling vs RAG) dựa trên câu hỏi của user

---

## 🧩 Cấu trúc tổng thể hệ thống

### Flow Diagram

```
┌───────────────────────────┐
│         User (FE Nuxt)    │
│ - Chat UI                 │
│ - Gửi tin nhắn            │
│ - Hiển thị text response  │
│ - Render rich UI (optional)│
└──────────────┬────────────┘
               │
               │ POST /api/chat
               │ { messages: [...] }
               ▼
┌───────────────────────────┐
│     Rails Backend API     │
│  (Proxy + Orchestration)  │
│ 1. Giữ API key Gemini     │
│ 2. Quản lý context chat   │
│ 3. Gọi Gemini API          │
│ 4. Parse tool_call từ Gemini│
│ 5. Thực thi tool (BE)     │
│ 6. Trả tool_result về Gemini│
│ 7. Nhận final response     │
│ 8. Trả về FE với format:   │
│    { content, toolResult? }│
└──────────────┬────────────┘
               │
               ▼
┌───────────────────────────┐
│        Gemini Model       │
│ - Hiểu câu hỏi            │
│ - Hỏi thêm nếu thiếu dữ liệu│
│ - Sinh phản hồi tự nhiên  │
│ - Khi cần → trả tool_call │
│ - Nhận tool_result → sinh response│
└──────────────┬────────────┘
               │
               ▼
┌───────────────────────────┐
│       Vector Database     │
│ (Supabase / Pinecone / Qdrant)│
│ - Lưu embedding tài liệu trường │
│ - Nhận query → trả đoạn text liên quan │
└───────────────────────────┘
```

### Architecture Decision

**BE làm hết logic tính toán:**
- ✅ Single source of truth (business logic)
- ✅ Reuse cho web/mobile/API
- ✅ Dễ maintain và scale
- ✅ Security (API keys, validation)

**FE chỉ render UI:**
- ✅ Focus vào UI/UX
- ✅ Render text response + rich UI components (optional)
- ✅ Không phải business logic

---

## 📋 Kế hoạch Triển Khai Từng Bước

### Bước 0 — Chuẩn bị tư tưởng & môi trường

**Mục tiêu**: Hiểu mục tiêu, chuẩn bị tài khoản và repo.

**Việc cần làm:**
1. Tạo project repo (FE: Nuxt, BE: Rails) nếu chưa có
2. Mở tài khoản Google Cloud / Gemini, lấy API key (đặt trong vault/dev secret, không commit vào git)
3. Cài .env trên cả BE (Rails) và dev config Nuxt (chỉ dùng FE key cho dev nếu bắt buộc)

**Deliverable**:
- ✅ Repo có sẵn
- ✅ `.env.example` file với template
- ✅ API key lưu an toàn trên BE (không commit vào git)

**Gợi ý làm nhanh:**
- Tạo file `.env.example` với các biến môi trường cần thiết
- Lưu API key Gemini trong `.env` (không commit)
- Setup `.gitignore` để ignore `.env` file

---

### Bước 1 — Hiểu flow tối giản (quick prototype)

**Mục tiêu**: Làm prototype chat có thể hỏi — thu thập input — gọi hàm tính — trả lời, **không cần vector DB ban đầu**.

**Việc cần làm:**

#### Frontend (Nuxt)

1. **Thiết kế UI chat cơ bản**:
   - Khung chat, input, message list
   - Hiển thị tin nhắn user và bot
   - Loading state khi đang gửi/chờ response

2. **Thiết kế "conversation manager" ở FE**:
   - Lưu messages trong state (ref/reactive)
   - Trạng thái đang chờ dữ liệu (isLoading)
   - Thêm message mới (user + bot)
   - Clear conversation

3. **API client cho chat**:
   - `POST /api/chat` endpoint
   - Gửi messages array đến BE
   - Nhận response từ BE
   - Error handling

4. **Render response**:
   - Hiển thị text response
   - Nếu có `toolResult` → render rich UI component (optional)

#### Backend (Rails)

1. **Chat endpoint**:
   - `POST /api/chat` nhận body từ FE
   - Thêm header API key Gemini
   - Call Gemini API
   - Parse tool_call từ Gemini response
   - Thực thi tool (BE)
   - Trả tool_result về Gemini
   - Nhận final response
   - Trả về FE với format chuẩn

**Deliverable**:
- ✅ Demo local: user chat → bot hỏi dữ liệu → trả kết quả tính toán (tự nhiên)

**Gợi ý làm nhanh:**
- Ban đầu có thể fake Gemini response bằng text cứng để tập flow tool call rồi bật thật sau
- Tập trung vào flow trước, không cần UI đẹp ngay

---

### Bước 2 — Thiết kế tool definitions & function-calling contract

**Mục tiêu**: Chuẩn hóa cách AI "gọi" hàm tính toán và cách BE thực thi, FE render UI.

**Việc cần làm:**

#### 1. Liệt kê tất cả "tool" (hàm) cần

**GPA Tools:**
- `calculateTargetGpa` - Tính GPA mục tiêu (nếu đạt toàn A)
- `calculateSimulationGpa` - Tính GPA simulation (phân bố điểm)
- `calculatePeGpa` - Tính GPA thể dục
- `calculateRequiredFinalScore` - Tính điểm cuối kỳ cần để qua môn
- `calculateFinalScore` - Tính điểm cuối kỳ (từ các thành phần)
- `convertToLetter` - Chuyển điểm số sang chữ cái (A, B, C, D, E, F)
- `convertToGpa` - Chuyển điểm thang 10 sang thang 4

**Tool Definitions (Chi tiết):**

```
Tool: calculateTargetGpa
Description: Tính GPA tối đa có thể đạt được nếu đạt toàn điểm A (4.0) cho các tín chỉ còn lại
Params:
  - completedCredits (integer, required): Số tín chỉ đã học
  - currentGpa (float, required): GPA hiện tại (0-4.0)
  - remainingCredits (integer, required): Số tín chỉ còn lại
  - targetGpa (float, optional): GPA mục tiêu (để so sánh)
Response:
  - maxGpaWithAllA (float): GPA tối đa nếu đạt toàn A
  - canReachTarget (boolean): Có thể đạt mục tiêu không
  - graduationClassification (object): Xếp loại tốt nghiệp
    - rank (string): "excellent" | "good" | "fair" | "average"
    - minGpa (float): GPA tối thiểu
    - maxGpa (float): GPA tối đa

Tool: calculateSimulationGpa
Description: Tính GPA dựa trên phân bố điểm giả định cho các tín chỉ còn lại
Params:
  - completedCredits (integer, required): Số tín chỉ đã học
  - currentGpa (float, required): GPA hiện tại (0-4.0)
  - remainingCredits (integer, required): Số tín chỉ còn lại
  - creditDistributions (array, required): Phân bố điểm
    - credits (integer): Số tín chỉ
    - gradeValue (string): "A+" | "A" | "A-" | "B+" | "B" | "B-" | "C+" | "C" | "C-" | "D"
Response:
  - finalGpa (float): GPA cuối cùng
  - remainingGpa (float): GPA phần còn lại
  - totalCredits (integer): Tổng số tín chỉ
  - graduationClassification (object): Xếp loại tốt nghiệp
  - distributionSummary (string): Tóm tắt phân bố điểm

Tool: calculatePeGpa
Description: Tính GPA thể dục (trung bình 3 điểm thể dục)
Params:
  - pe1 (float, required): Điểm thể dục 1 (0-10)
  - pe2 (float, required): Điểm thể dục 2 (0-10)
  - pe3 (float, required): Điểm thể dục 3 (0-10)
Response:
  - average (float): Điểm trung bình
  - isPass (boolean): Qua hay không (>= 2.0)

Tool: calculateRequiredFinalScore
Description: Tính điểm cuối kỳ cần đạt để qua môn
Params:
  - midterm (float, required): Điểm giữa kỳ (0-10)
  - attendance (float, required): Điểm chuyên cần (0-10)
  - finalWeight (float, default: 0.6): Trọng số cuối kỳ
  - midtermWeight (float, default: 0.3): Trọng số giữa kỳ
  - attendanceWeight (float, default: 0.1): Trọng số chuyên cần
  - minPassingScore (float, default: 5.0): Điểm tối thiểu để qua môn
Response:
  - requiredFinalScore (float): Điểm cuối kỳ cần đạt
  - formula (string): Công thức tính
  - currentScore (float): Điểm hiện tại (giữa kỳ + chuyên cần)
  - canPass (boolean): Có thể qua môn không (nếu đạt điểm tối đa)
```

#### 2. Response Format từ BE

```typescript
interface ChatResponse {
  content: string  // Text response từ Gemini
  toolResult?: {
    toolName: string  // "calculateTargetGpa" | "calculateSimulationGpa" | etc.
    data: Record<string, unknown>  // Tool result data
    uiComponent?: string  // Optional: FE component name để render rich UI
  }
  metadata?: {
    messageId: string
    timestamp: string
    intent?: string  // "calculation" | "question" | "rag"
  }
}
```

#### 3. Quy ước

- **BE**: Nhận `tool_call` từ Gemini → thực thi tool → trả `tool_result` về Gemini → nhận final response → trả về FE
- **FE**: Nhận response → hiển thị text → render rich UI component (nếu có `toolResult.uiComponent`)
- **Contract**: BE/FE cùng hiểu tool definitions và response format

**Deliverable**:
- ✅ File `tools.md` chứa contract các hàm (để FE/BE & prompt dùng chung)
- ✅ Response format specification

**Gợi ý làm nhanh:**
- Viết tool definitions dạng markdown hoặc JSON
- Đảm bảo FE và BE cùng hiểu contract này
- Test với mock data trước

---

### Bước 3 — Prompt engineering cơ bản & system message

**Mục tiêu**: Soạn prompt chuẩn để Gemini:
- Điều hướng hội thoại
- Hỏi thêm khi thiếu dữ liệu
- Trả `tool_call` khi cần

**Việc cần làm:**

1. **Viết 1 system message cố định** (role) mang giọng điệu:
   - Thân thiện
   - Hỏi phản hồi, không đoán bừa
   - Luôn hỏi khi thiếu dữ liệu

2. **Viết mẫu prompt cho từng intent**:
   - Tính điểm
   - Hỏi quy chế
   - Chuyển sang RAG

3. **Viết ví dụ `tool_call` JSON mẫu** trong prompt để Gemini biết format mong muốn

**Deliverable**:
- ✅ File `prompts.md` chứa system message + nhiều ví dụ user → expected tool_call hoặc response

**Ví dụ system message (conceptual):**
```
"Bạn là EduBot, trợ lý AI tư vấn về điểm số cho học viên Đại học Duy Tân.

Khi cần tính toán, trả về JSON tool_call:
{
  "function": "calculateRequiredFinalScore",
  "params": {
    "midterm": 7,
    "attendance": 9
  }
}

Nếu thiếu thông tin, hỏi 1 câu để lấy đủ input. Không đoán bừa.
Nếu không chắc, hỏi lại user để làm rõ."
```

**Gợi ý làm nhanh:**
- Bắt đầu với system message đơn giản
- Thêm ví dụ cụ thể để Gemini hiểu format
- Test và điều chỉnh prompt dần

---

### Bước 4 — Chuẩn bị tài liệu cho RAG (nếu cần)

**Mục tiêu**: Thu thập & chuẩn bị dữ liệu trường (quy chế, công thức).

**Việc cần làm:**

1. **Thu thập PDF / DOC / web pages**:
   - Quy chế điểm
   - Bảng quy đổi
   - Thông báo học vụ

2. **Chia text thành chunk nhỏ** (300–800 ký tự):
   - Mỗi chunk có: id + source + text
   - Đảm bảo mỗi chunk đủ ngữ nghĩa (1–3 câu)

3. **Tạo meta tags cho chunk**:
   - `type: 'grading_policy'`
   - `year: 2024`
   - `source: 'quy_che_2024.pdf'`

**Deliverable**:
- ✅ Folder `knowledge/` chứa các chunk file (CSV/JSON)

**Gợi ý làm nhanh:**
- Copy-paste các đoạn quan trọng trước
- Tách thủ công vài doc quan trọng để demo
- Không cần hoàn thiện ngay, có thể bổ sung sau

---

### Bước 5 — Chọn & cấu hình Vector DB + embedding

**Mục tiêu**: Triển khai lưu trữ embeddings để retrieval.

**Việc cần làm:**

1. **Chọn Vector DB** (dễ với intern):
   - **Chroma** (local) - Dễ nhất, không cần deploy
   - **Qdrant** (self-host) - Nếu muốn self-host
   - **Pinecone** (managed) - Nếu muốn managed service
   - **Supabase Vector** - Nếu đang dùng Supabase

2. **Chạy pipeline embedding**:
   - Dùng Gemini embedding (hoặc model embedding bạn có) để convert mỗi chunk → vector
   - Lưu vector + id + text vào Vector DB

3. **Viết API trên Rails**:
   - `POST /api/retrieve` nhận query text
   - Create embedding cho query
   - Query Vector DB
   - Trả top-k chunks

**Deliverable**:
- ✅ Vector DB chứa indexed chunks
- ✅ API trả top-k context

**Gợi ý làm nhanh:**
- Bắt đầu với Chroma local để prototype (không cần deploy)
- Sau đó có thể migrate sang Pinecone hoặc Supabase Vector nếu cần

---

### Bước 6 — Kết hợp RAG vào luồng chat

**Mục tiêu**: Khi AI nhận biết "cần kiến thức", nó sẽ dùng RAG.

**Việc cần làm:**

1. **FE gửi user message** → Rails gửi message tới Gemini ở chế độ phân tích intent

2. **Nếu Gemini trả `intent = ask_policy`**:
   - Rails gọi `retrieve(query)` → lấy 3 đoạn top
   - Rails gom system + context(top-k) + user question
   - Gọi Gemini để sinh câu trả lời dựa trên context

3. **Trả result về FE** hiển thị

**Deliverable**:
- ✅ Demo: Hỏi "Công thức tính điểm của trường là gì?" → bot trả lời chính xác từ tài liệu

**Gợi ý làm nhanh:**
- Bắt đầu với 1-2 câu hỏi mẫu để test RAG flow
- Verify bot trả lời đúng từ tài liệu, không hallucinate

---

### Bước 7 — Context & conversation memory (ngắn hạn)

**Mục tiêu**: Quản lý context hội thoại để AI biết lịch sử (session-based).

**Việc cần làm:**

1. **Ở Rails (hoặc FE) lưu lịch sử message**:
   - Tối đa N last messages (ví dụ: last 10)
   - Kèm metadata (time, user id)

2. **Khi gửi prompt tới Gemini**:
   - Đính kèm history để Gemini hiểu ngữ cảnh

**Deliverable**:
- ✅ Session context làm việc cho mỗi user (in-memory hoặc Redis nếu muốn)

**Gợi ý làm nhanh:**
- Bắt đầu với in-memory (session) cho mỗi user
- Sau đó có thể migrate sang Redis nếu cần persist

---

### Bước 8 — Bảo mật & vận hành

**Mục tiêu**: Tránh lộ API key và phòng trường hợp misuse.

**Việc cần làm:**

1. **API key Gemini**:
   - Chỉ lưu ở BE (Rails), không expose trên FE

2. **Thêm rate limit** cho endpoint `/api/chat`:
   - Giới hạn số requests per user
   - Queue requests nếu vượt limit

3. **Log tối giản**:
   - Message id, timestamp, intent
   - Không lưu toàn bộ nội dung nhạy cảm nếu không cần

**Deliverable**:
- ✅ Rails sử dụng env var để gọi Gemini
- ✅ Có basic logging + rate limit

**Gợi ý làm nhanh:**
- Setup rate limiting đơn giản (ví dụ: 10 requests/phút/user)
- Log basic info để debug, không log toàn bộ conversation

---

### Bước 9 — Test & verify (QA)

**Mục tiêu**: Đảm bảo bot hỏi đủ input, gọi đúng hàm, trả kết quả chính xác.

**Việc cần làm:**

1. **Viết danh sách test-case**:
   - Tính toán đủ input → trả đúng số
   - Thiếu input → bot hỏi cụ thể
   - Hỏi quy chế → trả nội dung đúng từ RAG
   - Tool calling → gọi đúng hàm với params đúng

2. **Chạy test thủ công** với test users (mentor)

**Deliverable**:
- ✅ Test matrix + bug list

**Gợi ý làm nhanh:**
- Viết test cases dạng checklist
- Test từng flow một (tool calling, RAG, conversation flow)
- Ghi nhận bugs và fix dần

---

### Bước 10 — Demo & feedback loop

**Mục tiêu**: Demo cho mentor, thu feedback, lặp lại.

**Việc cần làm:**

1. **Chuẩn bị 3 kịch bản demo**:
   - Tính điểm (tool calling)
   - Hỏi quy chế (RAG)
   - Tình huống lẫn lộn (bot phải hỏi)

2. **Ghi nhận phản hồi**:
   - Iterate prompts / chunking / tool signature
   - Fix bugs và cải thiện

**Deliverable**:
- ✅ Bản demo chạy local + report feedback

**Gợi ý làm nhanh:**
- Chuẩn bị demo scenarios trước
- Ghi nhận feedback cụ thể để cải thiện

---

## ✅ Checklist ngắn gọn (phiên bản "mỗi bước 1 file làm")

- [ ] **Repo + env**: Repo có sẵn, `.env.example`, API key lưu an toàn
- [ ] **Chat UI (Nuxt)**: Khung chat, input, message list
- [ ] **Rails proxy đến Gemini**: `POST /api/chat` endpoint
- [ ] **Tool definitions file**: `tools.md` với contract các hàm
- [ ] **Prompt templates**: `prompts.md` với system message + examples
- [ ] **Local compute tool**: Hàm tính điểm (calculateGPA, calculateRequiredFinalScore, etc.)
- [ ] **Tách docs → chunks**: Folder `knowledge/` với chunks
- [ ] **Vector DB & embedding pipeline**: Vector DB setup, embedding generation
- [ ] **RAG retrieval integration**: API retrieve + integration vào chat flow
- [ ] **Tests + demo**: Test matrix, demo scenarios

---

## 💡 Một số tips thực chiến (để làm nhanh, ít lỗi)

1. **Bắt đầu nhỏ**:
   - Prototype chỉ với 1 công thức + 1 document cho RAG
   - Mở rộng dần sau khi flow chạy ổn

2. **Prompt control**:
   - Luôn có system message cố định
   - Thêm "Do not hallucinate. If unsure, ask clarifying question."

3. **Tool calling safety**:
   - Validate params trước khi chạy hàm (type check, range check)
   - Handle edge cases (ví dụ: điểm âm, điểm > 10)

4. **Chunking**:
   - Giữ mỗi chunk đủ ngữ nghĩa (1–3 câu) để retrieval chính xác
   - Không chia quá nhỏ (mất context) hoặc quá lớn (tốn token)

5. **Logging**:
   - Log tool calls + their params để debug kết quả tính
   - Log RAG retrieval để verify đúng context

6. **Fallback**:
   - Nếu RAG không trả đoạn phù hợp, bot nên trả: "Mình chưa có tài liệu cụ thể, bạn muốn mình thử ước lượng không?" — đỡ hallucination

---

## 🎭 Kịch bản hội thoại mẫu (để demo)

### Kịch bản 1: Tính điểm (Tool Calling)

```
Bot: "Chào bạn, tôi có thể giúp gì về tính điểm hoặc quy chế học tập?"

User: "Tôi muốn tính điểm cuối kỳ cần bao nhiêu để qua môn"

Bot: "Bạn có thể cho tôi biết điểm giữa kỳ và điểm chuyên cần không?"

User: "Điểm giữa kỳ: 7, điểm chuyên cần: 9"

Bot: [Gọi tool calculateRequiredFinalScore] → "Dựa vào điểm giữa kỳ 7 và điểm chuyên cần 9, bạn cần đạt ít nhất 5.5 điểm cuối kỳ để qua môn."
```

### Kịch bản 2: Hỏi quy chế (RAG)

```
Bot: "Chào bạn, tôi có thể giúp gì về tính điểm hoặc quy chế học tập?"

User: "Muốn biết công thức tính điểm học phần ở trường."

System: route → RAG retrieval → attach top-3 đoạn từ Vector DB → Gemini trả lời dựa trên context

Bot: "Tại ĐH Duy Tân, điểm học phần = 10% chuyên cần + 30% giữa kỳ + 60% cuối kỳ. Bạn muốn tôi tính minh họa cho môn cụ thể không?"
```

### Kịch bản 3: Tình huống lẫn lộn (Bot phải hỏi)

```
Bot: "Chào bạn, tôi có thể giúp gì về tính điểm hoặc quy chế học tập?"

User: "Điểm số"

Bot: "Bạn muốn tôi tính giúp hay chỉ tra thông tin? Hoặc bạn có thể nói rõ hơn bạn muốn làm gì với điểm số?"

User: "Tính GPA"

Bot: "Bạn có thể cho tôi biết điểm số và số tín chỉ của các môn học không?"
```

---

## 📚 Tài Liệu Tham Khảo

- [Google Gemini API Documentation](https://ai.google.dev/docs)
- [Gemini API Pricing](https://ai.google.dev/pricing)
- [Vector Database Comparison](https://www.pinecone.io/learn/vector-database/)
- [RAG (Retrieval Augmented Generation) Guide](https://www.pinecone.io/learn/retrieval-augmented-generation/)

---

---

## 🔧 Implementation Details

### Frontend (Nuxt) Implementation

#### 1. API Client

```typescript
// app/composables/gpa/useChatApi.ts
import { useApiFetch } from '@/lib/api'

interface ChatMessage {
  role: 'user' | 'assistant'
  content: string
}

interface ChatResponse {
  content: string
  toolResult?: {
    toolName: string
    data: Record<string, unknown>
    uiComponent?: string
  }
  metadata?: {
    messageId: string
    timestamp: string
    intent?: string
  }
}

export const useChatApi = () => {
  const sendMessage = async (messages: ChatMessage[]): Promise<ChatResponse> => {
    const { data, error } = await useApiFetch<ChatResponse>('/api/chat', {
      method: 'POST',
      body: {
        messages
      }
    })

    if (error.value) {
      throw new Error(error.value.message || 'Failed to send message')
    }

    return data.value?.data || { content: '' }
  }

  return {
    sendMessage
  }
}
```

#### 2. Conversation Manager

```typescript
// app/composables/gpa/useChatConversation.ts
import { ref, reactive } from 'vue'
import { useChatApi } from './useChatApi'

interface Message {
  id: string
  role: 'user' | 'assistant'
  content: string
  timestamp: Date
  toolResult?: {
    toolName: string
    data: Record<string, unknown>
    uiComponent?: string
  }
}

export const useChatConversation = () => {
  const { sendMessage } = useChatApi()
  const messages = ref<Message[]>([])
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  const addMessage = (role: 'user' | 'assistant', content: string, toolResult?: Message['toolResult']) => {
    messages.value.push({
      id: `msg-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      role,
      content,
      timestamp: new Date(),
      toolResult
    })
  }

  const sendUserMessage = async (content: string) => {
    if (!content.trim()) return

    addMessage('user', content)
    isLoading.value = true
    error.value = null

    try {
      const response = await sendMessage(
        messages.value.map(msg => ({
          role: msg.role,
          content: msg.content
        }))
      )

      addMessage('assistant', response.content, response.toolResult)
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'An error occurred'
      addMessage('assistant', 'Xin lỗi, đã có lỗi xảy ra. Vui lòng thử lại.')
    } finally {
      isLoading.value = false
    }
  }

  const clearConversation = () => {
    messages.value = []
    error.value = null
  }

  return {
    messages,
    isLoading,
    error,
    sendUserMessage,
    clearConversation
  }
}
```

#### 3. Chat Component

```vue
<!-- app/components/gpa/ChatBox.vue -->
<script setup lang="ts">
import { useChatConversation } from '@/composables/gpa/useChatConversation'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import GpaResultCard from './GpaResultCard.vue'
import PeResultCard from './PeResultCard.vue'

const { messages, isLoading, sendUserMessage, clearConversation } = useChatConversation()
const inputValue = ref('')

const handleSend = async () => {
  if (!inputValue.value.trim() || isLoading.value) return

  const content = inputValue.value
  inputValue.value = ''
  await sendUserMessage(content)
}

const getToolComponent = (toolName: string) => {
  const componentMap: Record<string, any> = {
    calculateTargetGpa: 'GpaResultCard',
    calculateSimulationGpa: 'GpaResultCard',
    calculatePeGpa: 'PeResultCard'
  }
  return componentMap[toolName]
}
</script>

<template>
  <div class="chat-container">
    <div class="messages">
      <div v-for="msg in messages" :key="msg.id" class="message">
        <div :class="msg.role === 'user' ? 'user-message' : 'bot-message'">
          {{ msg.content }}
        </div>

        <!-- Render rich UI component if toolResult exists -->
        <component
          v-if="msg.toolResult && msg.toolResult.uiComponent"
          :is="getToolComponent(msg.toolResult.toolName)"
          :data="msg.toolResult.data"
        />
      </div>
    </div>

    <div class="input-area">
      <Input
        v-model="inputValue"
        @keyup.enter="handleSend"
        :disabled="isLoading"
        placeholder="Nhập câu hỏi..."
      />
      <Button @click="handleSend" :disabled="isLoading">
        {{ isLoading ? 'Đang gửi...' : 'Gửi' }}
      </Button>
    </div>
  </div>
</template>
```

### Backend (Rails) Implementation

#### 1. Chat Controller

```ruby
# app/controllers/api/chat_controller.rb
class Api::ChatController < ApplicationController
  def create
    messages = params[:messages]

    # Call Gemini API
    gemini_response = call_gemini_api(messages)

    # Parse tool_call if exists
    if gemini_response[:tool_call]
      tool_result = execute_tool(gemini_response[:tool_call])

      # Send tool_result back to Gemini
      final_response = call_gemini_api_with_tool_result(
        messages,
        gemini_response[:tool_call],
        tool_result
      )

      render json: {
        content: final_response[:content],
        toolResult: {
          toolName: gemini_response[:tool_call][:name],
          data: tool_result,
          uiComponent: get_ui_component(gemini_response[:tool_call][:name])
        }
      }
    else
      render json: {
        content: gemini_response[:content]
      }
    end
  rescue => e
    render json: { error: e.message }, status: 500
  end

  private

  def call_gemini_api(messages)
    # Implementation: Call Gemini API
    # Return: { content: "...", tool_call: {...} }
  end

  def execute_tool(tool_call)
    case tool_call[:name]
    when 'calculateTargetGpa'
      calculate_target_gpa(tool_call[:params])
    when 'calculateSimulationGpa'
      calculate_simulation_gpa(tool_call[:params])
    when 'calculatePeGpa'
      calculate_pe_gpa(tool_call[:params])
    when 'calculateRequiredFinalScore'
      calculate_required_final_score(tool_call[:params])
    else
      raise "Unknown tool: #{tool_call[:name]}"
    end
  end

  def calculate_target_gpa(params)
    completed_credits = params[:completedCredits].to_i
    current_gpa = params[:currentGpa].to_f
    remaining_credits = params[:remainingCredits].to_i
    target_gpa = params[:targetGpa]&.to_f

    total_credits = completed_credits + remaining_credits
    current_points = completed_credits * current_gpa
    future_points_all_a = remaining_credits * 4.0
    max_gpa = (current_points + future_points_all_a) / total_credits

    {
      maxGpaWithAllA: max_gpa.round(3),
      canReachTarget: target_gpa ? max_gpa >= target_gpa : nil,
      graduationClassification: get_graduation_classification(max_gpa)
    }
  end

  def calculate_simulation_gpa(params)
    # Implementation: Calculate simulation GPA
  end

  def calculate_pe_gpa(params)
    pe1 = params[:pe1].to_f
    pe2 = params[:pe2].to_f
    pe3 = params[:pe3].to_f

    average = (pe1 + pe2 + pe3) / 3.0

    {
      average: average.round(3),
      isPass: average >= 2.0
    }
  end

  def calculate_required_final_score(params)
    # Implementation: Calculate required final score
  end

  def get_graduation_classification(gpa)
    # Implementation: Get graduation classification
  end

  def get_ui_component(tool_name)
    {
      'calculateTargetGpa' => 'GpaResultCard',
      'calculateSimulationGpa' => 'GpaResultCard',
      'calculatePeGpa' => 'PeResultCard'
    }[tool_name]
  end
end
```

#### 2. Tool Service

```ruby
# app/services/gpa_calculator_service.rb
class GpaCalculatorService
  def self.calculate_target_gpa(params)
    # Tool implementation
  end

  def self.calculate_simulation_gpa(params)
    # Tool implementation
  end

  def self.calculate_pe_gpa(params)
    # Tool implementation
  end
end
```

---

## 📝 API Contract

### Request Format

```json
POST /api/chat
{
  "messages": [
    {
      "role": "user",
      "content": "Tôi muốn tính GPA mục tiêu"
    }
  ]
}
```

### Response Format

#### Success Response (Text only)

```json
{
  "data": {
    "content": "Để tính GPA mục tiêu, tôi cần biết số tín chỉ đã học, GPA hiện tại, và số tín chỉ còn lại.",
    "metadata": {
      "messageId": "msg-123",
      "timestamp": "2024-01-15T10:30:00Z",
      "intent": "question"
    }
  }
}
```

#### Success Response (With tool result)

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
      "messageId": "msg-124",
      "timestamp": "2024-01-15T10:31:00Z",
      "intent": "calculation"
    }
  }
}
```

#### Error Response

```json
{
  "errors": [
    {
      "message": "Invalid parameters",
      "details": "completedCredits must be >= 0"
    }
  ]
}
```

---

## 🎯 Examples

### Example 1: Calculate Target GPA

**User**: "Tôi muốn tính GPA mục tiêu"

**Bot**: "Để tính GPA mục tiêu, tôi cần biết số tín chỉ đã học, GPA hiện tại, và số tín chỉ còn lại."

**User**: "Đã học 60 tín, GPA hiện tại 3.0, còn lại 60 tín"

**Bot**: "Dựa vào thông tin của bạn, nếu đạt toàn điểm A (4.0) cho 60 tín chỉ còn lại, GPA tối đa của bạn sẽ là 3.52, đủ để đạt loại Giỏi."

**Response**:
```json
{
  "content": "Dựa vào thông tin của bạn...",
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
  }
}
```

### Example 2: Calculate PE GPA

**User**: "Tính GPA thể dục: 8, 7, 9"

**Bot**: "Dựa vào 3 điểm thể dục của bạn (8, 7, 9), GPA thể dục là 8.0, bạn đã qua môn."

**Response**:
```json
{
  "content": "Dựa vào 3 điểm thể dục...",
  "toolResult": {
    "toolName": "calculatePeGpa",
    "data": {
      "average": 8.0,
      "isPass": true
    },
    "uiComponent": "PeResultCard"
  }
}
```

---

## 🔐 Security Considerations

1. **API Key**: Chỉ lưu ở BE, không expose ra FE
2. **Rate Limiting**: Giới hạn số requests per user
3. **Input Validation**: Validate params trước khi thực thi tool
4. **Error Handling**: Không expose sensitive error messages
5. **Session Management**: Quản lý session cho conversation context

---

## 📊 Performance Considerations

1. **Caching**: Cache tool results cho cùng params
2. **Rate Limiting**: Prevent abuse
3. **Async Processing**: Long-running tools nên async
4. **Response Time**: Target < 2s cho tool execution
5. **Token Optimization**: Minimize token usage trong prompts

---

**Kết luận**: Kế hoạch này được thiết kế để intern chưa từng làm AI có thể làm từng bước một, mỗi bước có mục tiêu rõ ràng và deliverable cụ thể. Bắt đầu từ prototype đơn giản, sau đó thêm RAG và tool calling dần dần. **BE làm hết logic tính toán, FE chỉ render UI** - đảm bảo scalability và maintainability.

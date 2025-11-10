# BE-First Conversion Plan (AI Chatbox)

## Mục tiêu
- Backend chịu trách nhiệm toàn bộ AI + render UI (Tailwind) qua `toolResult.uiHtml`.
- Frontend chỉ render text `content` và `toolResult.uiHtml` (nếu có), không mapping component/data.

## Phạm vi thay đổi
- API: giữ nguyên `POST /api/chat` và response contract, bổ sung trường `toolResult.uiHtml` (Tailwind HTML).
- Service: mỗi tool trả về cả `data` (thô, optional) và `uiHtml` (ưu tiên hiển thị).
- Docs: đã cập nhật `ai-chatbox-architecture.md`, `chat-api-response.md`.

## Lộ trình triển khai (theo bước nhỏ)

### Bước 1: Hạ tầng render HTML
- Thêm module renderer tại `app/services/chats/ui_renderers/` (1 file/1 tool).
- API đầu ra: `render_<tool>(data) -> String` (HTML với Tailwind classes, không script).
- Unit test: trả về chuỗi không rỗng, có các class Tailwind cốt lõi.

Deliverables:
- `app/services/chats/ui_renderers/target_gpa_renderer.rb`
- Spec cơ bản (nếu dùng RSpec: `spec/services/chats/ui_renderers/...`)

### Bước 2: calculateTargetGpa → uiHtml
- Tạo renderer Tailwind cho `calculateTargetGpa`.
- Tích hợp tại `Chats::ProcessMessageService` để thêm `toolResult.uiHtml` khi tool này được gọi.
- Đảm bảo logic cũ không đổi, chỉ bổ sung trường `uiHtml`.

Deliverables:
- `toolResult.uiHtml` chứa card hiển thị maxGpa, canReachTarget, rank.
- Contract test: JSON có `toolResult.uiHtml` (string, non-empty).

### Bước 3: calculatePeGpa → uiHtml
- Renderer PE GPA (pass/fail, average, inputs summary).
- Tích hợp vào service tương tự Bước 2.

Deliverables:
- `toolResult.uiHtml` (Tailwind card) cho PE GPA.

### Bước 4: calculateSimulationGpa → uiHtml
- Renderer Simulation GPA (final, remaining, distributionSummary, rank).
- Tối ưu hiển thị list bằng bullets/badges.

Deliverables:
- `toolResult.uiHtml` cho Simulation GPA.

### Bước 5: Final Score tools → uiHtml
- `calculateRequiredFinalScore` và `calculateFinalScore` render các trường: scores, weights, verdict badges.
- Cảnh báo khi `requiredFinalScore` > 10.

Deliverables:
- `toolResult.uiHtml` cho hai tool final score.

### Bước 6: Tone & Accessibility
- Tone: đảm bảo `uiHtml` phản ánh tone (nhãn/badge/heading nhẹ) nhưng không lạm dụng emoji.
- A11y: dùng semantic tags (h2/h3, ul/li), contrast phù hợp (class `text-muted-foreground`, `text-primary`).

### Bước 7: Logging & Safety
- Log: `messageId`, `toolName`, có/không có `uiHtml`, chiều dài HTML.
- Safety: không render script/event inline; escape nội dung động.

### Bước 8: Tests & QA
- Contract test: `toolResult.uiHtml` là string HTML hợp lệ.
- Snapshot test (optional): so khớp mẫu HTML.
- Manual QA: dark/light theme, mobile width.

## Chuẩn HTML Tailwind (guideline)
- Container: `div.rounded-lg.border.bg-card.text-card-foreground.p-4`
- Title phụ: `div.text-sm.text-muted-foreground`
- Value: `div.mt-1.text-2xl.font-semibold`
- Badge: `span.inline-flex.items-center.px-2.py-0.5.rounded.bg-emerald-50.text-emerald-700` (đổi màu theo trạng thái)
- Không dùng `<script>` hoặc `on*` handlers.

## Quy tắc FE
- Render `data.content` như text.
- Nếu có `data.toolResult.uiHtml`: chèn vào vùng container an toàn.
- Không mapping component, không thêm logic hiển thị.

## Acceptance Criteria
- Mọi tool khi được gọi đều có `toolResult.uiHtml` (trừ khi lỗi).
- FE render đúng mà không cần logic mapping.
- Không có script, không lỗi HTML lộ liễu, hiển thị ổn dark/light.

## Kế hoạch rollout
- Merge theo tool (PR nhỏ, độc lập), bắt đầu từ TargetGpa → PeGpa → Simulation → FinalScore.
- Khi 2 tool đầu ổn định, bật `uiHtml` default cho FE.

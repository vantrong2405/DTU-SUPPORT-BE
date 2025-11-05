# GPA Calculator - Tính Toán GPA Thông Minh

## 📋 Tổng Quan

Hệ thống tính toán GPA thông minh giúp sinh viên Đại học Duy Tân:
- Dự đoán khả năng đạt GPA mục tiêu
- Tính toán GPA hiện tại và tích lũy
- Tính toán GPA thể dục
- Tính điểm qua môn theo trọng số
- Hỏi AI để nhận gợi ý học tập

---

## 📊 Dữ Liệu Định Nghĩa

### Xếp Loại Tốt Nghiệp Duy Tân

Bảng xếp loại tốt nghiệp chính thức của Đại học Duy Tân:

| Hạng | GPA Range (Thang 4) | Mô Tả |
|------|---------------------|-------|
| **Xuất sắc** | 3.60 – 4.00 | Hạng cao nhất, yêu cầu GPA ≥ 3.60 |
| **Giỏi** | 3.20 – 3.59 | Hạng tốt, yêu cầu GPA ≥ 3.20 |
| **Khá** | 2.50 – 3.19 | Hạng khá, yêu cầu GPA ≥ 2.50 |
| **Trung bình** | 2.00 – 2.49 | Hạng trung bình, yêu cầu GPA ≥ 2.00 |

**Lưu ý quan trọng:**
- Hạng tốt nghiệp có thể bị giảm nếu có **>5% tín chỉ học lại** hoặc bị kỷ luật
- Xếp loại dựa trên GPA tích lũy cuối cùng (thang điểm 4.0)

---

### Thang Điểm Duy Tân

Bảng chuyển đổi điểm số giữa các thang điểm của Đại học Duy Tân:

| Xếp Loại | Thang Điểm 10 | Điểm Chữ | Thang Điểm 4 | Trạng Thái |
|----------|---------------|----------|--------------|------------|
| **Giỏi** | 9.5 - 10.0 | A+ | 4.0 | Đạt |
| | 8.5 - 9.4 | A | 4.0 | Đạt |
| **Khá** | 8.0 - 8.4 | A- | 3.65 | Đạt |
| | 7.5 - 7.9 | B+ | 3.33 | Đạt |
| | 7.0 - 7.4 | B | 3.0 | Đạt |
| **Trung bình** | 6.5 - 6.9 | B- | 2.65 | Đạt |
| | 6.0 - 6.4 | C+ | 2.33 | Đạt |
| | 5.5 - 5.9 | C | 2.0 | Đạt |
| **Trung bình yếu** | 4.5 - 5.4 | C- | 1.65 | Đạt |
| **Trung bình yếu** | 4.0 - 4.4 | D | 1.0 | Đạt |
| **Kém** | 0.0 - 3.9 | F | 0.0 | Không đạt |

**Lưu ý quan trọng:**

1. **Thang điểm 4** là thang điểm đánh giá chính thức để:
   - Xét học vụ
   - Xét tốt nghiệp
   - Xếp hạng sinh viên

2. **Điểm F (0.0)**:
   - **Không được tích lũy** tín chỉ
   - **Bắt buộc phải học lại** môn học đó
   - Không tính vào GPA tích lũy

---

## 🟩 TAB 1 – TÍNH TOÁN MỤC TIÊU (GPA PROJECTION)

### 🎯 Mục Đích

Giúp sinh viên dự đoán xem mình có thể đạt GPA mục tiêu hoặc loại bằng mong muốn nếu cố gắng học tốt nhất (tức là đạt toàn điểm A cho số tín chỉ còn lại).

### 📥 Dữ Liệu Đầu Vào

Sinh viên sẽ nhập 4 giá trị:

| Trường | Label | Ý Nghĩa | Type | Validation | Ví Dụ |
|--------|-------|---------|------|------------|-------|
| `completedCredits` | Số tín đã học | Tổng số tín chỉ đã hoàn thành | Number (int) | ≥ 0 | 60 |
| `currentGpa` | GPA hiện tại | GPA tích lũy hiện tại (thang 4) | Number (float) | 0 ≤ value ≤ 4.0 | 3.0 |
| `targetGpa` | GPA mục tiêu | GPA mong muốn đạt được | Number (float) | 0.01 ≤ value ≤ 4.0 | 3.2 |
| `remainingCredits` | Số tín còn lại | Số tín chỉ chưa học | Number (int) | ≥ 1 | 65 |

### ⚙️ Cách Tính

Giả định rằng tất cả tín chỉ còn lại được điểm **A = 4.0**.

**Công thức:**

```
GPA_final = (current_gpa × credits_completed) + (4.0 × credits_remaining)
            ──────────────────────────────────────────────────────────
                          credits_completed + credits_remaining
```

**Ví dụ tính toán:**

Input:
- `completedCredits` = 60
- `currentGpa` = 3.0
- `targetGpa` = 3.2
- `remainingCredits` = 65

Calculation:
```
GPA_final = (3.0 × 60) + (4.0 × 65)
            ────────────────────────
                 60 + 65

         = 180 + 260
           ─────────
             125

         = 440 / 125
         = 3.520
```

Result: `GPA_final = 3.520`

### 📤 Kết Quả Đầu Ra

Hệ thống hiển thị:

1. **GPA dự kiến** nếu đạt toàn A → `GPA_final` (hiển thị với 3 chữ số thập phân)

2. **So sánh với mục tiêu:**

   **Nếu `GPA_final >= target_gpa`** → ✅ **"Có thể đạt mục tiêu!"**
   - Message: "Nếu đạt điểm A (4.0) ở tất cả các môn còn lại, bạn sẽ đạt GPA {GPA_final}, cao hơn mục tiêu của bạn."
   - Styling: Primary colors (success indicator)

   **Nếu `GPA_final < target_gpa`** → ❌ **"Khó đạt mục tiêu"**
   - Message: "Ngay cả khi đạt điểm A (4.0) ở tất cả các môn còn lại, GPA tối đa chỉ là {GPA_final}, thấp hơn mục tiêu."
   - Styling: Accent colors (warning indicator)

3. **Bằng tốt nghiệp tương ứng** (Optional - Future Enhancement):

   Hiển thị loại bằng tương ứng với `GPA_final`:

   | Hạng | GPA Range | Badge Color | Icon |
   |------|-----------|-------------|------|
   | **Xuất sắc** | 3.60 – 4.00 | Gold/Primary | ⭐ |
   | **Giỏi** | 3.20 – 3.59 | Primary | 🎓 |
   | **Khá** | 2.50 – 3.19 | Accent | 📜 |
   | **Trung bình** | 2.00 – 2.49 | Muted | 📄 |
   | **Yếu** | < 2.00 | Destructive | ⚠️ |

### 🧩 Mục Tiêu Của Tab Này

- Giúp sinh viên lên kế hoạch học tập và biết rõ liệu có thể đạt hạng mong muốn hay không
- Không cần nhập chi tiết từng môn học
- Dễ thao tác, chỉ cần 4 thông số là đủ

---

## 🟦 TAB 2 – TÍNH TOÁN GPA CHI TIẾT (GIẢ LẬP ĐIỂM)

### 🎯 Mục Đích

Giúp sinh viên tự giả lập kết quả học tập tương lai bằng cách phân bổ loại điểm (A, B, C...) cho số tín chỉ còn lại, để biết GPA cuối cùng sau toàn khóa học là bao nhiêu.

=> Mục đích là xem trước kết quả 4 năm học nếu họ dự đoán mình đạt kết quả như vậy.

### 📥 Dữ Liệu Đầu Vào

Sinh viên sẽ nhập các giá trị sau:

| Trường | Label | Ý Nghĩa | Type | Validation | Ví Dụ |
|--------|-------|---------|------|------------|-------|
| `completedCredits` | Số tín chỉ đã học | Tổng số tín chỉ đã hoàn thành | Number (int) | ≥ 0 | 60 |
| `currentGpa` | GPA hiện tại | GPA tích lũy hiện tại (thang 4) | Number (float) | 0 ≤ value ≤ 4.0 | 3.0 |
| `remainingCredits` | Số tín chỉ còn lại | Số tín chỉ chưa học | Number (int) | ≥ 1 | 60 |

👉 **Sinh viên sẽ nhập phân bố điểm giả định cho phần còn lại**, ví dụ:

| Loại điểm | Số tín chỉ | Thang điểm 4 tương ứng | Trạng thái |
|-----------|------------|------------------------|------------|
| A+ | 5 | 4.0 | Đạt |
| A | 10 | 4.0 | Đạt |
| A− | 5 | 3.65 | Đạt |
| B+ | 10 | 3.33 | Đạt |
| B | 10 | 3.0 | Đạt |
| B− | 5 | 2.65 | Đạt |
| C+ | 5 | 2.33 | Đạt |
| C | 5 | 2.0 | Đạt |
| C− | 3 | 1.65 | Đạt |
| D | 2 | 1.0 | Đạt |
| **(Tổng cộng = 60 tín còn lại)** | | | |

**Lưu ý quan trọng:**
- Tổng số tín chỉ trong phân bố điểm phải bằng `remainingCredits`.
- **Điểm F (0.0)**:
  - **Không được tích lũy** tín chỉ
  - **Bắt buộc phải học lại** môn học đó
  - **Không tính vào GPA tích lũy** (nên không nên nhập trong phân bố điểm giả định)

### ⚙️ Cách Tính

Hệ thống sẽ:

1. **Tính điểm quy đổi cho phần còn lại:**

   ```
   GPA_remaining = Σ(tín chỉ từng loại × điểm thang 4 tương ứng)
                  ────────────────────────────────────────────
                            tổng tín chỉ còn lại
   ```

   **Ví dụ:**
   - 5 tín A+ (4.0) = 5 × 4.0 = 20.0
   - 10 tín A (4.0) = 10 × 4.0 = 40.0
   - 5 tín A− (3.65) = 5 × 3.65 = 18.25
   - 10 tín B+ (3.33) = 10 × 3.33 = 33.3
   - 10 tín B (3.0) = 10 × 3.0 = 30.0
   - 5 tín B− (2.65) = 5 × 2.65 = 13.25
   - 5 tín C+ (2.33) = 5 × 2.33 = 11.65
   - 5 tín C (2.0) = 5 × 2.0 = 10.0
   - 3 tín C− (1.65) = 3 × 1.65 = 4.95
   - 2 tín D (1.0) = 2 × 1.0 = 2.0
   - **Tổng điểm quy đổi** = 20.0 + 40.0 + 18.25 + 33.3 + 30.0 + 13.25 + 11.65 + 10.0 + 4.95 + 2.0 = **183.4**
   - **GPA_remaining** = 183.4 / 60 = **3.057**

2. **Tính GPA toàn khóa (sau khi học xong):**

   ```
   GPA_final = (current_gpa × credits_completed) + (GPA_remaining × credits_remaining)
               ────────────────────────────────────────────────────────────────────────
                              credits_completed + credits_remaining
   ```

   **Ví dụ:**
   - `completedCredits` = 60
   - `currentGpa` = 3.0
   - `GPA_remaining` = 3.057
   - `remainingCredits` = 60

   ```
   GPA_final = (3.0 × 60) + (3.057 × 60)
               ───────────────────────────
                        60 + 60

            = 180 + 183.42
              ────────────
                 120

            = 363.42 / 120
            = 3.0285 ≈ 3.029
   ```

3. **Xác định loại bằng tốt nghiệp dự kiến** dựa trên `GPA_final`:

   | Hạng | GPA (thang 4) |
   |------|---------------|
   | **Xuất sắc** | 3.60 – 4.00 |
   | **Giỏi** | 3.20 – 3.59 |
   | **Khá** | 2.50 – 3.19 |
   | **Trung bình** | 2.00 – 2.49 |

### 📤 Kết Quả Đầu Ra

Hệ thống hiển thị:

1. **GPA toàn khóa dự kiến** (`GPA_final`) - hiển thị với 3 chữ số thập phân

2. **Xếp loại tốt nghiệp tương ứng**:
   - Badge với màu sắc và icon phù hợp
   - Hiển thị tên hạng (Xuất sắc, Giỏi, Khá, Trung bình)

3. **Tóm tắt giả lập**:
   - Ví dụ: "Bạn giả định đạt 15 tín A/A+, 20 tín B/B+, 10 tín C/C+, 5 tín C−/D → GPA toàn khóa 3.029 → Xếp loại Khá."
   - Hiển thị breakdown chi tiết phân bố điểm đã nhập

### 🧩 Mục Tiêu Của Tab Này

- Cho phép sinh viên chủ động thử nhiều kịch bản khác nhau (ví dụ: "Nếu mình đạt nhiều điểm B hơn thì GPA giảm thế nào?")
- Là mô phỏng thực tế hơn so với tab 1 (tab 1 chỉ giả định toàn A)
- Giúp sinh viên hiểu tác động của từng loại điểm lên GPA cuối cùng

### ✅ Tóm Tắt Ngắn Gọn

Tab 2 là nơi sinh viên giả lập phân bố điểm (A, B, C, D...) cho các tín chỉ còn lại.

Hệ thống dùng công thức cố định để tính GPA trung bình sau toàn khóa và hiển thị xếp loại dự kiến.

---

## 🟦 TAB 3 – GPA THỂ DỤC (Coming Soon)

### 🎯 Mục Đích

Công cụ tính GPA thể dục theo thang điểm DTU.

### 📥 Dữ Liệu Đầu Vào (Dự Kiến)

- Các môn thể dục đã học
- Điểm thể dục (có thể có thang điểm riêng)

---

## 🟨 TAB 4 – TÍNH ĐIỂM QUA MÔN

### 🎯 Mục Đích

Giúp sinh viên tính điểm thi cuối kỳ tối thiểu cần đạt để qua môn dựa trên điểm thành phần hiện có và tỷ lệ trọng số từng cột. Cho phép dự đoán điểm tổng kết và xếp loại nếu biết trước điểm thi cuối kỳ.

=> Mục đích là giúp sinh viên ước lượng khả năng qua môn trước khi thi và biết mình cần đạt bao nhiêu điểm trong thi cuối kỳ.

### 📥 Dữ Liệu Đầu Vào

Sinh viên sẽ nhập các giá trị sau:

| Trường | Label | Ý Nghĩa | Type | Validation | Ví Dụ |
|--------|-------|---------|------|------------|-------|
| `components` | Các thành phần điểm | Mảng các thành phần điểm đã có | Array | Required | [{name: "Chuyên cần", weight: 10, score: 9.0}] |
| `finalExamWeight` | Trọng số thi cuối kỳ (%) | Trọng số của điểm thi cuối kỳ | Number (float) | > 0, ≤ 100 | 50 |
| `minPassingScore` | Điểm tối thiểu để qua môn | Điểm tối thiểu cần đạt (thang 10) | Number (float) | 0 ≤ value ≤ 10.0 | 4.0 |
| `finalExamScore` | Điểm thi cuối kỳ (Optional) | Điểm thi cuối kỳ giả định để dự đoán | Number (float) | 0 ≤ value ≤ 10.0 | 8.0 |

👉 **Sinh viên nhập các cột điểm và trọng số tương ứng**, ví dụ:

| Thành phần | Trọng số (%) | Điểm đạt được | Ghi chú |
|-----------|--------------|---------------|---------|
| Chuyên cần | 10 | 9.0 | Điểm quá trình |
| Giữa kỳ | 20 | 7.0 | Điểm kiểm tra giữa kỳ |
| Đồ án | 10 | 8.5 | (Nếu có) |
| Sáng tạo | 10 | 7.5 | (Nếu có) |
| Cuối kỳ | 50 | (chưa có hoặc nhập để dự đoán) | Điểm thi cuối kỳ |

**Lưu ý quan trọng:**
- Tổng trọng số của tất cả thành phần (bao gồm thi cuối kỳ) phải = 100%
- Điểm thi cuối kỳ tối thiểu phải ≥ 1.0 (theo quy định trường)
- Điểm tổng kết ≥ 4.0 mới qua môn

### ⚙️ Cách Tính

Hệ thống sẽ:

1. **Tính điểm tổng kết (khi biết điểm thi cuối kỳ):**

   ```
   Điểm_tổng_kết = Σ(điểm_thành_phần × trọng_số_thành_phần) / 100
   ```

   **Ví dụ:**
   - Chuyên cần: 9.0 × 10% = 0.9
   - Giữa kỳ: 7.0 × 20% = 1.4
   - Đồ án: 8.5 × 10% = 0.85
   - Sáng tạo: 7.5 × 10% = 0.75
   - Cuối kỳ: 8.0 × 50% = 4.0
   - **Điểm_tổng_kết** = (90 + 140 + 85 + 75 + 400) / 100 = **7.9**

2. **Tính điểm thi tối thiểu cần để qua môn:**

   Giả sử tổng điểm các phần đã có là `partialScore` (theo %), và trọng số thi cuối kỳ là `examWeight`.

   ```
   Điểm_thi_cần = (Điểm_đạt_môn - partialScore) / (examWeight / 100)
   ```

   **Ví dụ:**
   - `partialScore` = 0.9 + 1.4 + 0.85 + 0.75 = 3.9
   - `examWeight` = 50%
   - `Điểm_đạt_môn` = 4.0

   ```
   Điểm_thi_cần = (4.0 - 3.9) / 0.5
                 = 0.1 / 0.5
                 = 0.2
   ```

   👉 **Kết luận:** Cần ít nhất 0.2 điểm cuối kỳ để qua môn, nhưng do quy định tối thiểu 1.0 → **Cần ít nhất 1.0 điểm cuối kỳ**.

   **Trường hợp đặc biệt:**
   - Nếu `Điểm_thi_cần < 1.0` → Trả về `1.0` (theo quy định tối thiểu)
   - Nếu `Điểm_thi_cần > 10.0` → Trả về `null` (không thể qua môn)

3. **Dự đoán điểm tổng kết khi biết điểm thi cuối kỳ:**

   ```
   Điểm_tổng_kết_dự_đoán = partialScore + (examScore × examWeight / 100)
   ```

   **Ví dụ:**
   - `partialScore` = 3.9
   - `examScore` = 9.0
   - `examWeight` = 50%

   ```
   Điểm_tổng_kết = 3.9 + (9.0 × 0.5)
                   = 3.9 + 4.5
                   = 8.4
   ```

   Result: `Điểm_tổng_kết = 8.4` → **Giỏi (A)**

   **Quy đổi sang điểm chữ và thang 4:**

   Dựa trên bảng thang điểm Duy Tân:
   - 8.4 → **A** (thang 4: 4.0)
   - 7.9 → **B+** (thang 4: 3.33)
   - 7.0 → **B** (thang 4: 3.0)
   - 6.0 → **C+** (thang 4: 2.33)
   - 5.0 → **C** (thang 4: 2.0)
   - 4.0 → **D** (thang 4: 1.0)
   - < 4.0 → **F** (thang 4: 0.0) → Không đạt

### 📤 Kết Quả Đầu Ra

Hệ thống hiển thị:

1. **Điểm thi tối thiểu cần để qua môn:**

   **Nếu có thể qua môn:**
   - "Bạn cần ít nhất **1.43** điểm cuối kỳ để qua môn (≥ 4.0 điểm tổng kết)."
   - Styling: Primary colors (success indicator)
   - Icon: ✅ CheckCircle

   **Nếu không thể qua môn:**
   - "Với điểm hiện tại, bạn không thể qua môn ngay cả khi đạt điểm tối đa (10.0) trong thi cuối kỳ."
   - Styling: Destructive colors (error indicator)
   - Icon: ❌ XCircle

2. **Dự đoán kết quả tổng kết khi nhập điểm thi cuối kỳ giả định:**

   - **Tổng điểm (thang 10):** Hiển thị với 2 chữ số thập phân: `7.90`
   - **Quy đổi sang thang 4:** Hiển thị với 2 chữ số thập phân: `3.33`
   - **Điểm chữ (A, B+, C, v.v.):** Badge với màu sắc phù hợp (A+/A: Primary, A-/B+: Accent, B/B-: Muted, C+/C/C-: Muted, D: Muted, F: Destructive)
   - **Trạng thái:**
     - **"Đạt"** (≥ 4.0) → Primary color, ✅ CheckCircle
     - **"Không đạt"** (< 4.0) → Destructive color, ❌ XCircle

3. **Biểu đồ nhỏ** (Optional - Future Enhancement):
   - Thanh progress hiển thị tổng điểm hiện có (%)
   - Dấu mốc thể hiện ngưỡng "qua môn" (4.0)

### 🧩 Mục Tiêu Của Tab Này

- Giúp sinh viên chủ động ước lượng khả năng qua môn trước khi thi
- Cho phép giả lập kết quả thi để biết mình sẽ đạt được gì
- Hỗ trợ tính toán linh hoạt cho mọi môn học (vì số lượng cột và % thay đổi tùy môn)
- Trực quan, dễ hiểu, không cần nhớ công thức

### ✅ Tóm Tắt Ngắn Gọn

Tab 4 là nơi sinh viên tính điểm thi cuối kỳ tối thiểu cần đạt để qua môn dựa trên điểm thành phần hiện có và tỷ lệ trọng số. Hệ thống hỗ trợ tính toán linh hoạt với nhiều thành phần điểm và trọng số khác nhau, cho phép dự đoán điểm tổng kết và xếp loại nếu biết trước điểm thi cuối kỳ.

---

## 🟦 TAB 5 – HỎI AI (Coming Soon)

### 🎯 Mục Đích

Đặt câu hỏi cho AI để nhận lời khuyên học tập thông minh dựa trên GPA và kế hoạch học tập.

### 📥 Dữ Liệu Đầu Vào (Dự Kiến)

- Câu hỏi của sinh viên
- Context: GPA hiện tại, mục tiêu, số tín chỉ còn lại

### 📤 Kết Quả Đầu Ra (Dự Kiến)

- Gợi ý học tập cá nhân hóa
- Lộ trình học tập
- Tips để cải thiện GPA

---

## 🎨 UI/UX Considerations

### Layout

- **Desktop:** 2-column grid (Form left, Result right) cho tab 1
- **Mobile:** 1-column stack (Form top, Result bottom)
- **Tabs:** Horizontal tabs với overflow scroll trên mobile

### Design Principles

- Tất cả màu sắc sử dụng design tokens (primary, accent, muted, etc.)
- Không hardcode màu sắc
- Support dark mode
- Internationalization ready (i18n keys)
- Accessibility: ARIA labels, keyboard navigation

### Responsive Behavior

- **Mobile (< 640px):** Full-width inputs, stacked buttons, smaller text
- **Tablet (640px - 1024px):** Same as mobile với larger spacing
- **Desktop (> 1024px):** 2-column layout, larger text, horizontal buttons

---

## 🔍 Edge Cases & Validation

### Common Validations

- **Negative numbers:** Chặn (min: 0)
- **GPA > 4.0:** Chặn (max: 4.0)
- **Zero credits:** Warning nếu `remainingCredits = 0`
- **Total credits = 0:** Return `null`, không hiển thị result
- **Division by zero:** Prevent với validation
- **NaN values:** Error handling

### Error Handling

- Validation errors hiển thị dưới mỗi input field
- Disable submit button khi form invalid
- Clear error messages bằng tiếng Việt

---

## ✅ Acceptance Criteria (Tab 1)

- [x] User có thể nhập 4 giá trị input
- [x] Form validation hoạt động đúng
- [x] Calculation chính xác với công thức
- [x] Hiển thị result với formatting đúng (3 decimal places)
- [x] So sánh với target GPA và hiển thị message phù hợp
- [x] Responsive trên mobile, tablet, desktop
- [x] Error handling cho edge cases
- [x] Dark mode support
- [x] Accessibility compliance

---

## 📝 Notes

- File này mô tả ý tưởng và requirements cho GPA Calculator
- Chi tiết implementation sẽ được update khi develop từng tab
- Tất cả tabs đều sử dụng chung design system và tokens

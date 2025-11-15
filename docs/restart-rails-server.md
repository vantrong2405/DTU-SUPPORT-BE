# Cách Restart Rails Server để Load ENV Mới

## Vấn đề

Sau khi update `.env.development`, Rails server vẫn dùng ENV cũ vì chưa restart.

## Giải pháp: Restart Rails Server

### Cách 1: Restart trong terminal đang chạy Rails

Nếu Rails server đang chạy trong terminal:
1. Nhấn `Ctrl+C` để stop server
2. Start lại: `rails server` hoặc `rails s`

### Cách 2: Kill process và start lại

```bash
# Kill Rails server process
pkill -f puma
# hoặc
killall puma

# Start lại Rails server
rails server
# hoặc
rails s
```

### Cách 3: Restart với specific port

```bash
# Kill process trên port 4000
lsof -ti:4000 | xargs kill -9

# Start lại
rails server -p 4000
```

## Kiểm tra ENV đã load chưa

Sau khi restart, kiểm tra logs để xác nhận ENV đã được load đúng.

Nếu vẫn thấy giá trị cũ → Rails server chưa restart hoặc ENV chưa được update đúng.

## Lưu ý

- `dotenv-rails` chỉ load ENV khi Rails start, không tự động reload
- Cần restart Rails server sau mỗi lần update `.env.development`
- Development mode có `config.enable_reloading = true` nhưng chỉ reload code, không reload ENV

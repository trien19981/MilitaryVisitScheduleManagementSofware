# Hướng dẫn cấu hình DNS cho api.thamhoi.io.vn

## Vấn đề hiện tại

Domain `api.thamhoi.io.vn` chưa được cấu hình DNS, nên không thể resolve được.

## Các bước cấu hình DNS

### Bước 1: Lấy IP server

Chạy lệnh sau để lấy IP server của bạn:

```bash
curl ifconfig.me
# hoặc
curl ipinfo.io/ip
```

Hoặc chạy script kiểm tra:
```bash
./scripts/check-dns.sh
```

### Bước 2: Đăng nhập quản lý DNS

Đăng nhập vào nhà cung cấp DNS của domain `thamhoi.io.vn`. Có thể là:
- Cloudflare
- Namecheap
- GoDaddy
- Hoặc nhà cung cấp khác

### Bước 3: Tạo A Record

Tạo một A record mới với thông tin sau:

- **Type**: `A`
- **Name**: `api` (hoặc `api.thamhoi.io.vn` tùy nhà cung cấp)
- **Value/IP**: IP server của bạn (ví dụ: `103.159.51.241`)
- **TTL**: `300` (5 phút) hoặc mặc định
- **Proxy**: `OFF` (tắt proxy nếu dùng Cloudflare, để Let's Encrypt có thể verify)

### Bước 4: Đợi DNS propagate

Sau khi tạo DNS record, đợi 5-30 phút để DNS propagate.

Kiểm tra DNS:
```bash
dig +short api.thamhoi.io.vn
# Phải trả về IP server của bạn
```

Hoặc:
```bash
nslookup api.thamhoi.io.vn
```

### Bước 5: Kiểm tra từ bên ngoài

Sau khi DNS đã propagate, test từ server:

```bash
curl http://api.thamhoi.io.vn/api/health
```

Nếu trả về kết quả (200 hoặc 401), DNS đã hoạt động.

## Lưu ý về Rate Limit

⚠ **QUAN TRỌNG**: Bạn đã vượt rate limit của Let's Encrypt:
- **Thời gian chờ**: Đến **05:02:59 UTC** (khoảng 1 giờ từ lần thử cuối)
- **Lý do**: Quá nhiều lần xác thực thất bại (5 lần) trong 1 giờ

**Giải pháp**:
1. Cấu hình DNS đúng trước
2. Đợi đến khi rate limit hết hạn
3. Sau đó mới chạy lại `./scripts/setup-ssl.sh`

## Kiểm tra DNS đã đúng chưa

Chạy script:
```bash
./scripts/check-dns.sh
```

Script sẽ:
- Kiểm tra DNS có resolve được không
- So sánh IP domain với IP server
- Test xem domain có thể truy cập được không

## Troubleshooting

### DNS không resolve được

1. Kiểm tra record đã được tạo chưa:
   ```bash
   dig api.thamhoi.io.vn
   ```

2. Kiểm tra TTL và đợi propagate

3. Kiểm tra từ nhiều DNS server:
   ```bash
   dig @8.8.8.8 api.thamhoi.io.vn
   dig @1.1.1.1 api.thamhoi.io.vn
   ```

### DNS đã đúng nhưng vẫn không truy cập được

1. Kiểm tra firewall:
   ```bash
   sudo ufw status
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

2. Kiểm tra Nginx reverse proxy:
   ```bash
   sudo systemctl status nginx
   sudo nginx -t
   ```

3. Kiểm tra Docker container:
   ```bash
   docker ps
   curl http://127.0.0.1:8000/api/health
   ```

## Sau khi DNS đã đúng

1. **Đợi rate limit hết hạn** (05:02:59 UTC)

2. **Kiểm tra lại DNS**:
   ```bash
   ./scripts/check-dns.sh
   ```

3. **Test đường dẫn acme-challenge**:
   ```bash
   ./scripts/test-acme-path.sh
   ```

4. **Chạy lại script setup SSL**:
   ```bash
   ./scripts/setup-ssl.sh
   ```

## Ví dụ cấu hình DNS

### Cloudflare
```
Type: A
Name: api
Content: 103.159.51.241
Proxy status: DNS only (OFF)
TTL: Auto
```

### Namecheap/GoDaddy
```
Type: A Record
Host: api
Value: 103.159.51.241
TTL: 300
```

### DirectAdmin/cPanel
```
Type: A
Name: api
Points to: 103.159.51.241
TTL: 300
```

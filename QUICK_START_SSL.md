# Hướng dẫn nhanh cấu hình SSL

## Bước 1: Khởi động Docker containers

```bash
docker compose up -d
# hoặc
docker-compose up -d
```

Kiểm tra containers đang chạy:
```bash
docker ps
```

## Bước 2: Cấu hình Reverse Proxy (BẮT BUỘC)

Reverse proxy cần thiết vì Docker container đang chạy trên port 8000, nhưng Let's Encrypt cần truy cập qua port 80.

### Chạy script tự động:

```bash
sudo ./scripts/setup-reverse-proxy-nginx.sh
```

### Hoặc kiểm tra xem đã cấu hình chưa:

```bash
# Kiểm tra Nginx có đang chạy không
sudo systemctl status nginx

# Kiểm tra cấu hình có tồn tại không
ls -la /etc/nginx/sites-available/api.thamquannhan.io.vn
ls -la /etc/nginx/sites-enabled/api.thamquannhan.io.vn
```

Nếu chưa có, chạy script ở trên.

## Bước 3: Kiểm tra Reverse Proxy hoạt động

```bash
# Test từ localhost port 8000 (trực tiếp container)
curl http://127.0.0.1:8000/api/health

# Test qua reverse proxy (port 80)
curl -H "Host: api.thamquannhan.io.vn" http://127.0.0.1/api/health

# Test từ domain bên ngoài
curl http://api.thamquannhan.io.vn/api/health
```

Nếu tất cả đều trả về kết quả, reverse proxy đã hoạt động đúng.

## Bước 4: Debug nếu có vấn đề

Chạy script debug để kiểm tra chi tiết:

```bash
./scripts/debug-acme-challenge.sh
```

Script này sẽ kiểm tra:
- File test có tồn tại trong container không
- Port 8000 có thể truy cập được không
- Reverse proxy có hoạt động không
- Domain có thể truy cập được từ bên ngoài không

## Bước 5: Chạy script setup SSL

Sau khi reverse proxy hoạt động đúng:

```bash
./scripts/setup-ssl.sh
```

Khi script hỏi "Bạn đã cấu hình reverse proxy chưa?", nhấn **y** nếu đã cấu hình.

## Troubleshooting

### Lỗi: "404 Not Found" khi truy cập acme-challenge

**Nguyên nhân:** Reverse proxy chưa được cấu hình hoặc cấu hình sai.

**Giải pháp:**
1. Chạy script cấu hình reverse proxy:
   ```bash
   sudo ./scripts/setup-reverse-proxy-nginx.sh
   ```

2. Kiểm tra cấu hình:
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

3. Kiểm tra logs:
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

### Lỗi: "502 Bad Gateway"

**Nguyên nhân:** Docker container chưa chạy hoặc port 8000 không thể truy cập.

**Giải pháp:**
1. Kiểm tra container:
   ```bash
   docker ps
   ```

2. Khởi động lại container:
   ```bash
   docker compose restart nginx
   ```

3. Kiểm tra port 8000:
   ```bash
   curl http://127.0.0.1:8000/api/health
   ```

### Lỗi: "Connection refused"

**Nguyên nhân:** Firewall chưa mở port 80 hoặc Nginx trên host chưa chạy.

**Giải pháp:**
1. Mở firewall:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

2. Khởi động Nginx:
   ```bash
   sudo systemctl start nginx
   sudo systemctl enable nginx
   ```

### Domain không resolve được

**Nguyên nhân:** DNS chưa được cấu hình đúng.

**Giải pháp:**
```bash
# Kiểm tra DNS
dig +short api.thamquannhan.io.vn

# Phải trả về IP server của bạn (ví dụ: 103.159.51.241)
```

## Kiểm tra từng bước

1. ✅ Docker containers đang chạy: `docker ps`
2. ✅ Port 8000 có thể truy cập: `curl http://127.0.0.1:8000/api/health`
3. ✅ Reverse proxy đã cấu hình: `ls /etc/nginx/sites-enabled/api.thamquannhan.io.vn`
4. ✅ Nginx trên host đang chạy: `sudo systemctl status nginx`
5. ✅ Domain có thể truy cập: `curl http://api.thamquannhan.io.vn/api/health`
6. ✅ Port 80 đã mở: `sudo ufw status | grep 80`

Sau khi tất cả các bước trên đều OK, bạn có thể chạy `setup-ssl.sh` thành công!

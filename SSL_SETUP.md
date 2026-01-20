# Hướng dẫn cấu hình SSL/HTTPS cho domain api.thamquannhan.io.vn

## Yêu cầu trước khi bắt đầu

1. **Domain đã được cấu hình DNS**: Domain `api.thamquannhan.io.vn` phải trỏ về IP server của bạn
2. **Port 80 và 443 đã được mở**: Đảm bảo firewall cho phép traffic trên port 80 và 443
3. **Certbot đã được cài đặt**: Script sẽ tự động cài đặt nếu chưa có

## Các bước cấu hình

### Bước 0: Cấu hình ban đầu (nếu chưa có SSL)

Nếu bạn chưa có SSL certificate và muốn chạy ứng dụng với HTTP trước, sử dụng cấu hình HTTP-only:

```bash
cp docker/nginx/default.conf.http-only docker/nginx/default.conf
docker-compose restart nginx
```

Sau đó bạn có thể truy cập API qua HTTP: `http://api.thamquannhan.io.vn`

### Bước 1: Cập nhật email trong script

Mở file `scripts/setup-ssl.sh` và thay đổi dòng:
```bash
EMAIL="your-email@example.com"  # Thay đổi email của bạn
```
thành email thật của bạn (email này sẽ nhận thông báo về SSL certificate).

### Bước 2: Chạy script cấu hình SSL

```bash
cd /path/to/MilitaryVisitScheduleManagementSofware
./scripts/setup-ssl.sh
```

Script sẽ:
- Tạo các thư mục cần thiết
- Tạm thời cấu hình Nginx để certbot có thể verify domain
- Lấy SSL certificate từ Let's Encrypt
- Copy certificate vào container
- Cấu hình Nginx với HTTPS

### Bước 3: Kiểm tra

Sau khi script chạy xong, kiểm tra:
```bash
# Kiểm tra container đang chạy
docker ps

# Kiểm tra logs của nginx
docker logs schedule-be-nginx

# Test HTTPS
curl https://api.thamquannhan.io.vn/api/health
```

## Gia hạn SSL certificate tự động

SSL certificate từ Let's Encrypt có thời hạn 90 ngày. Để tự động gia hạn:

### Cách 1: Sử dụng cron job (khuyến nghị)

Thêm vào crontab:
```bash
crontab -e
```

Thêm dòng sau (chạy vào lúc 2 giờ sáng mỗi ngày):
```bash
0 2 * * * /path/to/MilitaryVisitScheduleManagementSofware/scripts/renew-ssl.sh >> /var/log/ssl-renew.log 2>&1
```

### Cách 2: Chạy thủ công

```bash
./scripts/renew-ssl.sh
```

## Cấu hình đã được thay đổi

1. **docker-compose.yml**:
   - Expose port 443 (HTTPS)
   - Mount thư mục SSL certificates
   - Mount thư mục certbot

2. **docker/nginx/default.conf**:
   - Cấu hình HTTP server (port 80) redirect sang HTTPS
   - Cấu hình HTTPS server (port 443) với SSL
   - Thêm security headers
   - Hỗ trợ Let's Encrypt verification

3. **public/index.php**:
   - Đã thêm domain vào CORS allowed origins

## Xử lý lỗi

### Lỗi: "Domain not found" hoặc "DNS resolution failed"
- Kiểm tra DNS: `dig api.thamquannhan.io.vn`
- Đảm bảo domain đã trỏ về đúng IP server

### Lỗi: "Port 80 already in use"
- Kiểm tra xem có service nào đang dùng port 80 không: `sudo lsof -i :80`
- Dừng service đó hoặc thay đổi port trong docker-compose.yml

### Lỗi: "Certificate creation failed"
- Đảm bảo domain đã trỏ về IP server
- Đảm bảo port 80 đã được mở
- Kiểm tra logs: `docker logs schedule-be-nginx`

### Lỗi khi truy cập HTTPS: "SSL certificate problem"
- Kiểm tra certificate đã được copy đúng chưa: `ls -la docker/nginx/ssl/`
- Kiểm tra quyền truy cập file: `chmod 644 docker/nginx/ssl/*.pem`
- Restart nginx: `docker-compose restart nginx`

## Lưu ý

- **Development**: Nếu đang phát triển local, bạn có thể sử dụng `default.conf.http-only` để chạy với HTTP
- **Production**: Luôn sử dụng HTTPS trong production
- **Certificate expiry**: Certificate sẽ hết hạn sau 90 ngày, cần gia hạn định kỳ
- **Backup**: Luôn backup certificates trước khi thay đổi
- **Lần đầu setup**: Nếu chưa có SSL certificate, nginx sẽ không khởi động được với config HTTPS. Hãy sử dụng `default.conf.http-only` trước, sau đó chạy script setup-ssl.sh

## Tài liệu tham khảo

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://certbot.eff.org/docs/)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)

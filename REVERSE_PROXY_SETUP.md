# Hướng dẫn cấu hình Reverse Proxy cho Docker Container

Vì Docker container đang sử dụng port **8080** (HTTP) và **8443** (HTTPS) thay vì port 80/443, bạn cần cấu hình reverse proxy trên host để forward traffic từ port 80/443 đến container.

## Tại sao cần Reverse Proxy?

- Let's Encrypt chỉ có thể verify domain qua port 80 (HTTP) và 443 (HTTPS)
- Domain `api.thamquannhan.io.vn` cần truy cập được qua port 80/443 chuẩn
- Reverse proxy sẽ forward request từ port 80/443 → 8080/8443 của container

## Cách 1: Sử dụng Nginx trên Host (Khuyến nghị)

### Bước 1: Cài đặt Nginx (nếu chưa có)

```bash
sudo apt-get update
sudo apt-get install -y nginx
```

### Bước 2: Tạo cấu hình Nginx

Tạo file cấu hình mới:

```bash
sudo nano /etc/nginx/sites-available/api.thamquannhan.io.vn
```

Nội dung file:

```nginx
# HTTP server - forward đến Docker container port 8000
server {
    listen 80;
    server_name api.thamquannhan.io.vn;

    # Allow Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Forward tất cả request khác đến Docker container
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# HTTPS server - forward đến Docker container port 8443
server {
    listen 443 ssl http2;
    server_name api.thamquannhan.io.vn;

    # SSL certificates (sẽ được cấu hình sau khi có SSL)
    ssl_certificate /etc/letsencrypt/live/api.thamquannhan.io.vn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.thamquannhan.io.vn/privkey.pem;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Forward tất cả request đến Docker container
    location / {
        proxy_pass https://127.0.0.1:8443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Bỏ qua SSL verification khi forward đến container
        proxy_ssl_verify off;
    }
}
```

### Bước 3: Kích hoạt site

```bash
sudo ln -s /etc/nginx/sites-available/api.thamquannhan.io.vn /etc/nginx/sites-enabled/
sudo nginx -t  # Kiểm tra cấu hình
sudo systemctl reload nginx
```

## Cách 2: Sử dụng Apache trên Host

### Bước 1: Cài đặt Apache (nếu chưa có)

```bash
sudo apt-get update
sudo apt-get install -y apache2
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod ssl
sudo a2enmod headers
```

### Bước 2: Tạo cấu hình Apache

Tạo file cấu hình:

```bash
sudo nano /etc/apache2/sites-available/api.thamquannhan.io.vn.conf
```

Nội dung file:

```apache
<VirtualHost *:80>
    ServerName api.thamquannhan.io.vn
    
    # Allow Let's Encrypt verification
    ProxyPreserveHost On
    ProxyPass /.well-known/acme-challenge/ http://127.0.0.1:8000/.well-known/acme-challenge/
    ProxyPassReverse /.well-known/acme-challenge/ http://127.0.0.1:8000/.well-known/acme-challenge/
    
    # Forward tất cả request khác
    ProxyPass / http://127.0.0.1:8000/
    ProxyPassReverse / http://127.0.0.1:8000/
    
    # Headers
    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"
</VirtualHost>

<VirtualHost *:443>
    ServerName api.thamquannhan.io.vn
    
    # SSL Configuration (sẽ được cấu hình sau khi có SSL)
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/api.thamquannhan.io.vn/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/api.thamquannhan.io.vn/privkey.pem
    
    # Forward tất cả request đến Docker container
    ProxyPreserveHost On
    ProxyPass / https://127.0.0.1:8443/
    ProxyPassReverse / https://127.0.0.1:8443/
    
    # Headers
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
</VirtualHost>
```

### Bước 3: Kích hoạt site

```bash
sudo a2ensite api.thamquannhan.io.vn.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

## Cách 3: Sử dụng iptables (Đơn giản nhưng ít linh hoạt)

Nếu bạn chỉ muốn forward port đơn giản:

```bash
# Forward port 80 -> 8000
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000

# Forward port 443 -> 8443
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

# Lưu cấu hình (Ubuntu/Debian)
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save
```

## Kiểm tra cấu hình

Sau khi cấu hình reverse proxy:

1. **Kiểm tra port 80 có thể truy cập được:**
   ```bash
   curl -I http://api.thamquannhan.io.vn/api/health
   ```

2. **Kiểm tra từ bên ngoài:**
   ```bash
   curl http://api.thamquannhan.io.vn/.well-known/acme-challenge/test
   ```

3. **Kiểm tra logs:**
   ```bash
   # Nginx
   sudo tail -f /var/log/nginx/access.log
   sudo tail -f /var/log/nginx/error.log
   
   # Apache
   sudo tail -f /var/log/apache2/access.log
   sudo tail -f /var/log/apache2/error.log
   ```

## Lưu ý quan trọng

1. **Firewall**: Đảm bảo port 80 và 443 đã được mở:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

2. **DNS**: Domain phải trỏ về IP server của bạn

3. **SSL Certificate**: Sau khi cấu hình reverse proxy, bạn có thể chạy script `setup-ssl.sh` để lấy SSL certificate. Certificate sẽ được cài trên host (Nginx/Apache), không phải trong Docker container.

4. **Dual SSL**: Nếu bạn muốn SSL cả trên host và container, cần cấu hình SSL passthrough thay vì SSL termination.

## Troubleshooting

### Lỗi: "502 Bad Gateway"
- Kiểm tra Docker container đang chạy: `docker ps`
- Kiểm tra port 8000/8443 có thể truy cập: `curl http://127.0.0.1:8000`

### Lỗi: "Connection refused"
- Kiểm tra firewall: `sudo ufw status`
- Kiểm tra service đang chạy: `sudo systemctl status nginx` hoặc `sudo systemctl status apache2`

### Let's Encrypt không verify được
- Đảm bảo port 80 đã được mở và forward đúng
- Kiểm tra `.well-known/acme-challenge/` có thể truy cập được từ bên ngoài
- Test: `curl http://api.thamquannhan.io.vn/.well-known/acme-challenge/test`

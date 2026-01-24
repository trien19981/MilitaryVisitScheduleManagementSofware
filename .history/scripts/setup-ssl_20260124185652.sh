#!/bin/bash

# Script để cấu hình SSL certificate cho domain api.thamhoi.io.vn
# Sử dụng Let's Encrypt với certbot

DOMAIN="api.thamhoi.io.vn"
EMAIL="trien19981@gmail.com"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Xác định lệnh docker compose (có thể là docker-compose hoặc docker compose)
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "Lỗi: Không tìm thấy docker-compose hoặc docker compose!"
    exit 1
fi

echo "=== Cấu hình SSL cho domain: $DOMAIN ==="
echo ""
echo "⚠ QUAN TRỌNG: Docker container đang sử dụng port 8000 (HTTP) và 8443 (HTTPS)"
echo "Let's Encrypt cần truy cập domain qua port 80 để verify."
echo "Bạn cần cấu hình reverse proxy trên host để forward port 80 -> 8000"
echo "Xem file REVERSE_PROXY_SETUP.md để biết cách cấu hình"
echo ""
read -p "Bạn đã cấu hình reverse proxy chưa? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Vui lòng cấu hình reverse proxy trước khi tiếp tục!"
    echo "Xem hướng dẫn trong file REVERSE_PROXY_SETUP.md"
    exit 1
fi
echo ""

# Tạo thư mục cần thiết
echo "Tạo thư mục cho SSL certificates..."
mkdir -p "$PROJECT_DIR/docker/nginx/ssl"
mkdir -p "$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge"
mkdir -p "$PROJECT_DIR/docker/certbot/conf"

# Đặt quyền cho thư mục certbot để nginx có thể đọc
chmod -R 755 "$PROJECT_DIR/docker/certbot/www"
chown -R $(id -u):$(id -g) "$PROJECT_DIR/docker/certbot/www" 2>/dev/null || true

# Kiểm tra xem certbot đã được cài đặt chưa
if ! command -v certbot &> /dev/null; then
    echo "Certbot chưa được cài đặt. Đang cài đặt..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update
        sudo apt-get install -y certbot
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install certbot
    else
        echo "Vui lòng cài đặt certbot thủ công từ https://certbot.eff.org/"
        exit 1
    fi
fi

# Kiểm tra xem domain đã trỏ về server chưa
echo "Kiểm tra DNS..."
if ! dig +short $DOMAIN | grep -q .; then
    echo "CẢNH BÁO: Domain $DOMAIN có thể chưa được cấu hình DNS đúng!"
    echo "Vui lòng đảm bảo domain trỏ về IP server của bạn trước khi tiếp tục."
    read -p "Bạn có muốn tiếp tục không? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Tạm thời chỉnh sửa nginx config để chỉ listen port 80 (cho certbot verification)
echo "Tạm thời cấu hình Nginx cho certbot..."
cat > "$PROJECT_DIR/docker/nginx/default.conf.tmp" << 'EOF'
server {
    listen 80;
    server_name api.thamhoi.io.vn localhost;
    root /var/www/html/public;

    index index.php;

    # Allow Let's Encrypt verification - QUAN TRỌNG: phải đặt trước location /
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Backup config hiện tại và sử dụng config tạm
# Kiểm tra xem có file backup chưa, nếu chưa thì backup
if [ ! -f "$PROJECT_DIR/docker/nginx/default.conf.backup" ]; then
    cp "$PROJECT_DIR/docker/nginx/default.conf" "$PROJECT_DIR/docker/nginx/default.conf.backup"
fi
cp "$PROJECT_DIR/docker/nginx/default.conf.tmp" "$PROJECT_DIR/docker/nginx/default.conf"

# Kiểm tra và khởi động containers nếu chưa chạy
echo "Kiểm tra containers..."
cd "$PROJECT_DIR"
if ! docker ps | grep -q schedule-be-nginx; then
    echo "Khởi động containers..."
    $DOCKER_COMPOSE up -d
else
    echo "Restart Nginx container..."
    $DOCKER_COMPOSE restart nginx
fi

# Đợi nginx khởi động và kiểm tra
echo "Đợi Nginx khởi động..."
sleep 5

# Kiểm tra xem nginx đã sẵn sàng chưa
if ! docker exec schedule-be-nginx nginx -t 2>/dev/null; then
    echo "Cảnh báo: Có lỗi trong cấu hình Nginx. Kiểm tra logs:"
    docker logs schedule-be-nginx --tail 20
fi

# Kiểm tra xem đường dẫn acme-challenge có thể truy cập được không
echo "Kiểm tra đường dẫn acme-challenge..."
TEST_FILE="$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge/test.txt"
mkdir -p "$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge"
echo "test-acme-challenge" > "$TEST_FILE"
chmod 644 "$TEST_FILE"
sleep 3

# Test từ bên ngoài (nếu có curl)
if command -v curl &> /dev/null; then
    echo "Đang test đường dẫn acme-challenge..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/.well-known/acme-challenge/test.txt" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✓ Đường dẫn acme-challenge có thể truy cập được (HTTP $HTTP_CODE)"
    else
        echo "⚠ Cảnh báo: Không thể truy cập đường dẫn acme-challenge (HTTP $HTTP_CODE)"
        echo "Kiểm tra:"
        echo "  - Domain đã trỏ về IP server: $(dig +short $DOMAIN 2>/dev/null | head -1 || echo 'Không thể resolve')"
        echo "  - Port 80 đã được mở"
        echo "  - Nginx container đang chạy: $(docker ps --format '{{.Names}}' | grep -q schedule-be-nginx && echo 'Có' || echo 'Không')"
        echo "  - Kiểm tra logs nginx: docker logs schedule-be-nginx --tail 10"
        echo ""
        echo "Thử truy cập thủ công:"
        echo "  curl http://$DOMAIN/.well-known/acme-challenge/test.txt"
    fi
fi
rm -f "$TEST_FILE"

# Lấy SSL certificate
echo "Đang lấy SSL certificate từ Let's Encrypt..."
certbot certonly \
    --webroot \
    --webroot-path="$PROJECT_DIR/docker/certbot/www" \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN"

# Tìm đường dẫn certificates (có thể ở nhiều vị trí khác nhau)
CERT_PATH=""
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    CERT_PATH="/etc/letsencrypt"
elif [ -f "$HOME/.local/share/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    CERT_PATH="$HOME/.local/share/letsencrypt"
elif [ -f "$PROJECT_DIR/docker/certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
    CERT_PATH="$PROJECT_DIR/docker/certbot/conf"
fi

# Kiểm tra xem certificate đã được tạo thành công chưa
if [ -n "$CERT_PATH" ] && [ -f "$CERT_PATH/live/$DOMAIN/fullchain.pem" ]; then
    echo "SSL certificate đã được tạo thành công!"
    echo "Certificate location: $CERT_PATH/live/$DOMAIN/"
    
    # Copy certificates vào thư mục docker
    echo "Copy certificates vào thư mục docker..."
    cp "$CERT_PATH/live/$DOMAIN/fullchain.pem" "$PROJECT_DIR/docker/nginx/ssl/fullchain.pem"
    cp "$CERT_PATH/live/$DOMAIN/privkey.pem" "$PROJECT_DIR/docker/nginx/ssl/privkey.pem"
    
    # Đặt quyền phù hợp
    chmod 644 "$PROJECT_DIR/docker/nginx/ssl/fullchain.pem"
    chmod 600 "$PROJECT_DIR/docker/nginx/ssl/privkey.pem"
    
    # Khôi phục config HTTPS
    echo "Khôi phục cấu hình HTTPS..."
    rm "$PROJECT_DIR/docker/nginx/default.conf"
    # Sử dụng file HTTPS config (nếu có) hoặc backup
    if [ -f "$PROJECT_DIR/docker/nginx/default.conf.https" ]; then
        cp "$PROJECT_DIR/docker/nginx/default.conf.https" "$PROJECT_DIR/docker/nginx/default.conf"
    elif [ -f "$PROJECT_DIR/docker/nginx/default.conf.backup" ]; then
        cp "$PROJECT_DIR/docker/nginx/default.conf.backup" "$PROJECT_DIR/docker/nginx/default.conf"
    else
        echo "Lỗi: Không tìm thấy file cấu hình HTTPS!"
        exit 1
    fi
    
    # Restart nginx với config HTTPS
    echo "Khởi động lại Nginx với cấu hình HTTPS..."
    cd "$PROJECT_DIR"
    $DOCKER_COMPOSE restart nginx
    
    # Đợi nginx khởi động
    sleep 3
    
    # Kiểm tra nginx đã chạy thành công chưa
    if docker exec schedule-be-nginx nginx -t 2>/dev/null; then
        echo ""
        echo "=== Hoàn tất! ==="
        echo "SSL certificate đã được cấu hình thành công!"
        echo "Domain của bạn: https://$DOMAIN"
        echo ""
        echo "Lưu ý: Certificate sẽ hết hạn sau 90 ngày."
        echo "Để tự động gia hạn, thêm vào crontab:"
        echo "0 2 * * * $PROJECT_DIR/scripts/renew-ssl.sh >> /var/log/ssl-renew.log 2>&1"
    else
        echo "Cảnh báo: Có lỗi trong cấu hình Nginx. Kiểm tra logs:"
        echo "docker logs schedule-be-nginx"
    fi
else
    echo "Lỗi: Không thể tạo SSL certificate!"
    echo "Vui lòng kiểm tra:"
    echo "1. Domain đã trỏ về IP server chưa"
    echo "2. Port 80 đã được mở chưa"
    echo "3. Nginx container đã chạy chưa"
    echo "4. Email trong script đã được cập nhật chưa"
    
    # Khôi phục config cũ
    rm "$PROJECT_DIR/docker/nginx/default.conf"
    if [ -f "$PROJECT_DIR/docker/nginx/default.conf.backup" ]; then
        cp "$PROJECT_DIR/docker/nginx/default.conf.backup" "$PROJECT_DIR/docker/nginx/default.conf"
        $DOCKER_COMPOSE restart nginx
    fi
    exit 1
fi

# Xóa file tạm
rm -f "$PROJECT_DIR/docker/nginx/default.conf.tmp"

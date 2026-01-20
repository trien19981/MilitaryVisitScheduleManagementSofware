#!/bin/bash

# Script tự động cấu hình Nginx reverse proxy

DOMAIN="api.thamquannhan.io.vn"
NGINX_SITES_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
CONFIG_FILE="$NGINX_SITES_DIR/$DOMAIN"

echo "=== Cấu hình Nginx Reverse Proxy cho $DOMAIN ==="
echo ""

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then 
    echo "Vui lòng chạy script với quyền sudo: sudo $0"
    exit 1
fi

# Kiểm tra Nginx đã được cài đặt chưa
if ! command -v nginx &> /dev/null; then
    echo "Nginx chưa được cài đặt. Đang cài đặt..."
    apt-get update
    apt-get install -y nginx
fi

# Tạo cấu hình Nginx
echo "Tạo cấu hình Nginx..."
cat > "$CONFIG_FILE" << EOF
# HTTP server - forward đến Docker container port 8080
server {
    listen 80;
    server_name $DOMAIN;

    # Allow Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # Forward tất cả request khác đến Docker container
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# HTTPS server - sẽ được cấu hình sau khi có SSL certificate
# server {
#     listen 443 ssl http2;
#     server_name $DOMAIN;
#     ...
# }
EOF

# Kích hoạt site
if [ ! -L "$NGINX_ENABLED_DIR/$DOMAIN" ]; then
    ln -s "$CONFIG_FILE" "$NGINX_ENABLED_DIR/$DOMAIN"
    echo "✓ Đã kích hoạt site $DOMAIN"
else
    echo "Site $DOMAIN đã được kích hoạt"
fi

# Kiểm tra cấu hình
echo "Kiểm tra cấu hình Nginx..."
if nginx -t; then
    echo "✓ Cấu hình hợp lệ"
    echo "Đang reload Nginx..."
    systemctl reload nginx
    echo "✓ Đã reload Nginx"
    echo ""
    echo "=== Hoàn tất! ==="
    echo "Reverse proxy đã được cấu hình thành công"
    echo "Port 80 sẽ forward đến Docker container port 8000"
    echo ""
    echo "Kiểm tra:"
    echo "  curl -I http://$DOMAIN/api/health"
else
    echo "✗ Có lỗi trong cấu hình Nginx!"
    exit 1
fi

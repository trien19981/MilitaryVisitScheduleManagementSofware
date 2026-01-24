#!/bin/bash

# Script để gia hạn SSL certificate tự động

DOMAIN="api.thamhoi.io.vn"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Gia hạn SSL certificate cho domain: $DOMAIN ==="

# Gia hạn certificate
certbot renew --quiet

# Tìm đường dẫn certificates
CERT_PATH=""
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    CERT_PATH="/etc/letsencrypt"
elif [ -f "$HOME/.local/share/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    CERT_PATH="$HOME/.local/share/letsencrypt"
elif [ -f "$PROJECT_DIR/docker/certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
    CERT_PATH="$PROJECT_DIR/docker/certbot/conf"
fi

# Kiểm tra xem certificate mới đã được tạo chưa
if [ -n "$CERT_PATH" ] && [ -f "$CERT_PATH/live/$DOMAIN/fullchain.pem" ]; then
    echo "Copy certificates mới vào container..."
    
    # Copy certificates vào thư mục docker
    cp "$CERT_PATH/live/$DOMAIN/fullchain.pem" "$PROJECT_DIR/docker/nginx/ssl/fullchain.pem"
    cp "$CERT_PATH/live/$DOMAIN/privkey.pem" "$PROJECT_DIR/docker/nginx/ssl/privkey.pem"
    
    # Đặt quyền phù hợp
    chmod 644 "$PROJECT_DIR/docker/nginx/ssl/fullchain.pem"
    chmod 600 "$PROJECT_DIR/docker/nginx/ssl/privkey.pem"
    
    # Reload nginx để áp dụng certificate mới
    if docker exec schedule-be-nginx nginx -s reload 2>/dev/null; then
        echo "SSL certificate đã được gia hạn thành công!"
    else
        echo "Lỗi: Không thể reload nginx. Kiểm tra logs:"
        echo "docker logs schedule-be-nginx"
        exit 1
    fi
else
    echo "Không có certificate mới để cập nhật hoặc không tìm thấy certificate."
fi

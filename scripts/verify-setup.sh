#!/bin/bash

# Script kiểm tra toàn bộ setup trước khi chạy SSL

DOMAIN="api.thamquannhan.io.vn"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Kiểm tra toàn bộ setup ==="
echo ""

ALL_OK=true

# 1. Kiểm tra DNS
echo "1. Kiểm tra DNS..."
if dig +short $DOMAIN 2>/dev/null | grep -q .; then
    IP=$(dig +short $DOMAIN | head -1)
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "unknown")
    
    if [ "$IP" = "$SERVER_IP" ]; then
        echo "✓ DNS đã trỏ đúng: $DOMAIN -> $IP"
    else
        echo "⚠ DNS trỏ về: $IP (Server IP: $SERVER_IP)"
        echo "  Có thể DNS chưa propagate hoàn toàn"
    fi
else
    echo "✗ DNS chưa resolve được!"
    ALL_OK=false
fi
echo ""

# 2. Kiểm tra Docker containers
echo "2. Kiểm tra Docker containers..."
if docker ps | grep -q schedule-be-nginx; then
    echo "✓ Docker container schedule-be-nginx đang chạy"
else
    echo "✗ Docker container schedule-be-nginx KHÔNG chạy!"
    echo "  Chạy: docker compose up -d"
    ALL_OK=false
fi
echo ""

# 3. Kiểm tra port 8000 (container)
echo "3. Kiểm tra port 8000 (Docker container)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8000/api/health" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
    echo "✓ Port 8000 hoạt động (HTTP $HTTP_CODE)"
else
    echo "✗ Port 8000 không hoạt động (HTTP $HTTP_CODE)"
    ALL_OK=false
fi
echo ""

# 4. Kiểm tra reverse proxy
echo "4. Kiểm tra reverse proxy..."
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "✓ Nginx (host) đang chạy"
    
    if [ -f "/etc/nginx/sites-enabled/$DOMAIN" ] || [ -f "/etc/nginx/sites-available/$DOMAIN" ]; then
        echo "✓ Cấu hình reverse proxy tồn tại"
    else
        echo "✗ Cấu hình reverse proxy KHÔNG tồn tại"
        echo "  Chạy: sudo ./scripts/setup-reverse-proxy-nginx.sh"
        ALL_OK=false
    fi
else
    echo "✗ Nginx (host) KHÔNG chạy!"
    echo "  Chạy: sudo systemctl start nginx"
    ALL_OK=false
fi
echo ""

# 5. Kiểm tra domain có thể truy cập từ bên ngoài
echo "5. Kiểm tra domain từ bên ngoài..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$DOMAIN/api/health" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
    echo "✓ Domain có thể truy cập được (HTTP $HTTP_CODE)"
else
    echo "⚠ Domain trả về HTTP $HTTP_CODE hoặc không thể truy cập"
    echo "  Có thể DNS chưa propagate hoàn toàn"
fi
echo ""

# 6. Kiểm tra đường dẫn acme-challenge
echo "6. Kiểm tra đường dẫn acme-challenge..."
mkdir -p "$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge"
echo "test-$(date +%s)" > "$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge/test.txt"
chmod 644 "$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge/test.txt"
sleep 2

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/.well-known/acme-challenge/test.txt" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Đường dẫn acme-challenge hoạt động (HTTP 200)"
    CONTENT=$(curl -s "http://$DOMAIN/.well-known/acme-challenge/test.txt" 2>/dev/null)
    echo "  Nội dung: $CONTENT"
else
    echo "✗ Đường dẫn acme-challenge không hoạt động (HTTP $HTTP_CODE)"
    echo "  Kiểm tra:"
    echo "    - File có tồn tại trong container không?"
    echo "    - Reverse proxy có forward đúng không?"
    ALL_OK=false
fi
rm -f "$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge/test.txt"
echo ""

# 7. Kiểm tra rate limit
echo "7. Kiểm tra rate limit Let's Encrypt..."
CURRENT_TIME=$(date +%s)
RATE_LIMIT_TIME=$(date -d "2026-01-20 05:02:59 UTC" +%s 2>/dev/null || echo "0")

if [ "$RATE_LIMIT_TIME" -gt "$CURRENT_TIME" ]; then
    WAIT_SECONDS=$((RATE_LIMIT_TIME - CURRENT_TIME))
    WAIT_MINUTES=$((WAIT_SECONDS / 60))
    echo "⚠ Rate limit còn hiệu lực"
    echo "  Cần đợi thêm: $WAIT_MINUTES phút (đến 05:02:59 UTC)"
    echo "  Sau đó mới có thể chạy setup-ssl.sh"
else
    echo "✓ Rate limit đã hết hạn, có thể thử lại"
fi
echo ""

# Kết luận
echo "=== Kết luận ==="
if [ "$ALL_OK" = true ] && [ "$RATE_LIMIT_TIME" -le "$CURRENT_TIME" ]; then
    echo "✓ Tất cả đã sẵn sàng!"
    echo "Bạn có thể chạy: ./scripts/setup-ssl.sh"
elif [ "$ALL_OK" = true ]; then
    echo "✓ Cấu hình đã đúng, nhưng cần đợi rate limit hết hạn"
    echo "Đợi đến 05:02:59 UTC rồi chạy: ./scripts/setup-ssl.sh"
else
    echo "✗ Còn một số vấn đề cần khắc phục (xem trên)"
fi

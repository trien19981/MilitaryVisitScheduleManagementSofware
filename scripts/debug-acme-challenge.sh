#!/bin/bash

# Script debug để kiểm tra đường dẫn acme-challenge

DOMAIN="api.thamquannhan.io.vn"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Debug đường dẫn acme-challenge ==="
echo ""

# 1. Kiểm tra file test có tồn tại trong container không
echo "1. Kiểm tra file trong Docker container..."
TEST_FILE="$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge/test.txt"
mkdir -p "$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge"
echo "test-content-$(date +%s)" > "$TEST_FILE"
chmod 644 "$TEST_FILE"

echo "File test đã được tạo tại: $TEST_FILE"
echo "Nội dung: $(cat $TEST_FILE)"
echo ""

# 2. Kiểm tra từ bên trong container
echo "2. Kiểm tra từ bên trong Docker container..."
if docker exec schedule-be-nginx ls -la /var/www/certbot/.well-known/acme-challenge/test.txt 2>/dev/null; then
    echo "✓ File tồn tại trong container"
else
    echo "✗ File KHÔNG tồn tại trong container"
    echo "Kiểm tra volume mount..."
    docker exec schedule-be-nginx ls -la /var/www/certbot/ 2>/dev/null || echo "Thư mục /var/www/certbot không tồn tại"
fi
echo ""

# 3. Test từ localhost port 8000
echo "3. Test từ localhost port 8000 (Docker container)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8000/.well-known/acme-challenge/test.txt" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Port 8000 trả về HTTP 200"
    curl "http://127.0.0.1:8000/.well-known/acme-challenge/test.txt" 2>/dev/null
else
    echo "✗ Port 8000 trả về HTTP $HTTP_CODE"
fi
echo ""

# 4. Test từ localhost port 80 (qua reverse proxy)
echo "4. Test từ localhost port 80 (qua reverse proxy)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1/.well-known/acme-challenge/test.txt" -H "Host: $DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Port 80 (reverse proxy) trả về HTTP 200"
    curl "http://127.0.0.1/.well-known/acme-challenge/test.txt" -H "Host: $DOMAIN" 2>/dev/null
else
    echo "✗ Port 80 trả về HTTP $HTTP_CODE"
    echo "Có thể reverse proxy chưa được cấu hình"
fi
echo ""

# 5. Test từ domain bên ngoài
echo "5. Test từ domain bên ngoài..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/.well-known/acme-challenge/test.txt" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Domain trả về HTTP 200"
    curl "http://$DOMAIN/.well-known/acme-challenge/test.txt" 2>/dev/null
else
    echo "✗ Domain trả về HTTP $HTTP_CODE"
    echo "Kiểm tra:"
    echo "  - Reverse proxy đã được cấu hình chưa?"
    echo "  - Nginx/Apache trên host đang chạy?"
    echo "  - Firewall đã mở port 80?"
fi
echo ""

# 6. Kiểm tra Nginx config trong container
echo "6. Kiểm tra cấu hình Nginx trong container..."
docker exec schedule-be-nginx cat /etc/nginx/conf.d/default.conf | grep -A 5 "acme-challenge" || echo "Không tìm thấy cấu hình acme-challenge"
echo ""

# 7. Kiểm tra reverse proxy trên host
echo "7. Kiểm tra reverse proxy trên host..."
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "✓ Nginx (host) đang chạy"
    if [ -f "/etc/nginx/sites-enabled/$DOMAIN" ] || [ -f "/etc/nginx/sites-available/$DOMAIN" ]; then
        echo "✓ Cấu hình Nginx cho $DOMAIN tồn tại"
        echo "Nội dung cấu hình:"
        cat /etc/nginx/sites-available/$DOMAIN 2>/dev/null || cat /etc/nginx/sites-enabled/$DOMAIN 2>/dev/null | head -20
    else
        echo "✗ Cấu hình Nginx cho $DOMAIN KHÔNG tồn tại"
        echo "Chạy: sudo ./scripts/setup-reverse-proxy-nginx.sh"
    fi
elif systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
    echo "✓ Apache đang chạy"
    if [ -f "/etc/apache2/sites-enabled/$DOMAIN.conf" ] || [ -f "/etc/apache2/sites-available/$DOMAIN.conf" ]; then
        echo "✓ Cấu hình Apache cho $DOMAIN tồn tại"
    else
        echo "✗ Cấu hình Apache cho $DOMAIN KHÔNG tồn tại"
    fi
else
    echo "✗ Không có reverse proxy nào đang chạy!"
    echo "Chạy: sudo ./scripts/setup-reverse-proxy-nginx.sh"
fi
echo ""

# 8. Kiểm tra logs
echo "8. Kiểm tra logs Nginx container..."
docker logs schedule-be-nginx --tail 10 2>&1 | grep -i "error\|warn" || echo "Không có lỗi trong logs"
echo ""

echo "=== Kết luận ==="
echo "Nếu port 8000 trả về 200 nhưng domain trả về 404, bạn cần cấu hình reverse proxy"
echo "Chạy: sudo ./scripts/setup-reverse-proxy-nginx.sh"

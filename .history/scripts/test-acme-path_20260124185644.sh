#!/bin/bash

# Script test đường dẫn acme-challenge

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_FILE="$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge/test.txt"

echo "=== Test đường dẫn acme-challenge ==="
echo ""

# 1. Tạo file test
echo "1. Tạo file test..."
mkdir -p "$PROJECT_DIR/docker/certbot/www/.well-known/acme-challenge"
echo "test-content-$(date +%s)" > "$TEST_FILE"
chmod 644 "$TEST_FILE"

echo "File đã được tạo tại: $TEST_FILE"
echo "Nội dung: $(cat $TEST_FILE)"
echo ""

# 2. Kiểm tra file trong container
echo "2. Kiểm tra file trong Docker container..."
if docker exec schedule-be-nginx ls -la /var/www/certbot/.well-known/acme-challenge/test.txt 2>/dev/null; then
    echo "✓ File tồn tại trong container"
    echo "Nội dung trong container:"
    docker exec schedule-be-nginx cat /var/www/certbot/.well-known/acme-challenge/test.txt 2>/dev/null
else
    echo "✗ File KHÔNG tồn tại trong container"
    echo "Kiểm tra volume mount..."
    docker exec schedule-be-nginx ls -la /var/www/certbot/ 2>/dev/null || echo "Thư mục không tồn tại"
fi
echo ""

# 3. Test từ localhost port 8000
echo "3. Test từ localhost port 8000 (trực tiếp container)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8000/.well-known/acme-challenge/test.txt" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Port 8000 trả về HTTP 200"
    echo "Nội dung:"
    curl "http://127.0.0.1:8000/.well-known/acme-challenge/test.txt" 2>/dev/null
else
    echo "✗ Port 8000 trả về HTTP $HTTP_CODE"
    echo "Response:"
    curl "http://127.0.0.1:8000/.well-known/acme-challenge/test.txt" 2>/dev/null
fi
echo ""

# 4. Test qua reverse proxy (port 80)
echo "4. Test qua reverse proxy (port 80)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://api.thamhoi.io.vn/.well-known/acme-challenge/test.txt" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Domain trả về HTTP 200"
    echo "Nội dung:"
    curl "http://api.thamhoi.io.vn/.well-known/acme-challenge/test.txt" 2>/dev/null
else
    echo "✗ Domain trả về HTTP $HTTP_CODE"
    echo "Response:"
    curl "http://api.thamhoi.io.vn/.well-known/acme-challenge/test.txt" 2>/dev/null
fi
echo ""

# 5. Kiểm tra cấu hình Nginx trong container
echo "5. Kiểm tra cấu hình Nginx trong container..."
docker exec schedule-be-nginx cat /etc/nginx/conf.d/default.conf | grep -A 3 "acme-challenge" || echo "Không tìm thấy cấu hình"
echo ""

# 6. Kiểm tra logs Nginx
echo "6. Kiểm tra logs Nginx container (10 dòng cuối)..."
docker logs schedule-be-nginx --tail 10 2>&1 | grep -i "acme\|error\|404" || echo "Không có log liên quan"
echo ""

echo "=== Kết luận ==="
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Đường dẫn acme-challenge hoạt động đúng!"
    echo "Bạn có thể chạy script setup-ssl.sh"
else
    echo "✗ Vẫn còn vấn đề với đường dẫn acme-challenge"
    echo ""
    echo "Kiểm tra thêm:"
    echo "1. File có tồn tại trong container không?"
    echo "2. Cấu hình Nginx có đúng không?"
    echo "3. Volume mount có đúng không?"
fi

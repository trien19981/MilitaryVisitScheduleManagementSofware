#!/bin/bash

# Script kiểm tra DNS configuration

DOMAIN="api.thamhoi.io.vn"

echo "=== Kiểm tra DNS cho domain: $DOMAIN ==="
echo ""

# 1. Kiểm tra DNS resolution
echo "1. Kiểm tra DNS resolution..."
if dig +short $DOMAIN 2>/dev/null | grep -q .; then
    IP=$(dig +short $DOMAIN | head -1)
    echo "✓ Domain resolve được: $IP"
else
    echo "✗ Domain KHÔNG resolve được!"
    echo "Vui lòng cấu hình DNS A record cho $DOMAIN"
    exit 1
fi

# 2. Kiểm tra IP server hiện tại
echo ""
echo "2. Kiểm tra IP server hiện tại..."
SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "Không thể lấy IP")
echo "IP server: $SERVER_IP"

# 3. So sánh
echo ""
echo "3. So sánh..."
if [ "$IP" = "$SERVER_IP" ]; then
    echo "✓ DNS đã trỏ đúng về IP server!"
else
    echo "✗ DNS chưa trỏ đúng!"
    echo "  Domain trỏ về: $IP"
    echo "  Server IP: $SERVER_IP"
    echo ""
    echo "Vui lòng cấu hình DNS A record:"
    echo "  Type: A"
    echo "  Name: api.thamhoi.io.vn"
    echo "  Value: $SERVER_IP"
    echo "  TTL: 300 (hoặc mặc định)"
fi

# 4. Kiểm tra từ bên ngoài
echo ""
echo "4. Test từ bên ngoài..."
if command -v curl &> /dev/null; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://$DOMAIN/api/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
        echo "✓ Domain có thể truy cập được (HTTP $HTTP_CODE)"
    else
        echo "⚠ Domain trả về HTTP $HTTP_CODE hoặc không thể truy cập"
    fi
fi

echo ""
echo "=== Hướng dẫn cấu hình DNS ==="
echo ""
echo "1. Đăng nhập vào quản lý DNS của domain thamhoi.io.vn"
echo "2. Tạo A record mới:"
echo "   - Type: A"
echo "   - Name: api (hoặc api.thamhoi.io.vn)"
echo "   - Value: $SERVER_IP"
echo "   - TTL: 300"
echo ""
echo "3. Đợi DNS propagate (thường 5-30 phút)"
echo "4. Kiểm tra lại: dig +short $DOMAIN"
echo ""
echo "5. Sau khi DNS đã đúng, đợi rate limit hết hạn (05:02:59 UTC)"
echo "   rồi chạy lại: ./scripts/setup-ssl.sh"

#!/bin/bash

# Script kiểm tra tất cả các port phổ biến để tìm port trống

echo "=== Kiểm tra các port phổ biến ==="
echo ""

PORTS=(80 443 8000 8080 8443 8888 9000 3000 5000)

for port in "${PORTS[@]}"; do
    if command -v lsof &> /dev/null; then
        if sudo lsof -ti :$port &> /dev/null; then
            PID=$(sudo lsof -ti :$port | head -1)
            PROCESS=$(ps aux | grep "^[^ ]* *$PID " | grep -v grep | awk '{print $11}' | head -1)
            echo "⚠ Port $port: ĐANG SỬ DỤNG bởi PID $PID ($PROCESS)"
        else
            echo "✓ Port $port: TRỐNG"
        fi
    elif command -v netstat &> /dev/null; then
        if sudo netstat -tuln | grep -q ":$port "; then
            echo "⚠ Port $port: ĐANG SỬ DỤNG"
        else
            echo "✓ Port $port: TRỐNG"
        fi
    elif command -v ss &> /dev/null; then
        if sudo ss -tuln | grep -q ":$port "; then
            echo "⚠ Port $port: ĐANG SỬ DỤNG"
        else
            echo "✓ Port $port: TRỐNG"
        fi
    fi
done

echo ""
echo "=== Gợi ý ==="
echo "Nếu port 8000 cũng bị chiếm, bạn có thể đổi sang port khác trong docker-compose.yml"
echo "Ví dụ: 8888:80 hoặc 9000:80"

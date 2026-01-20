#!/bin/bash

# Script kiểm tra port 80 và 443 đang được sử dụng bởi service nào

echo "=== Kiểm tra port 80 và 443 ==="
echo ""

# Kiểm tra port 80
echo "Port 80:"
if command -v netstat &> /dev/null; then
    PORT80=$(netstat -tuln | grep ':80 ' || echo "")
elif command -v ss &> /dev/null; then
    PORT80=$(ss -tuln | grep ':80 ' || echo "")
elif command -v lsof &> /dev/null; then
    PORT80=$(lsof -i :80 || echo "")
else
    PORT80=""
fi

if [ -n "$PORT80" ]; then
    echo "⚠ Port 80 đang được sử dụng:"
    echo "$PORT80"
    echo ""
    
    # Tìm process ID
    if command -v lsof &> /dev/null; then
        PID=$(lsof -ti :80 | head -1)
        if [ -n "$PID" ]; then
            echo "Process đang sử dụng port 80:"
            ps aux | grep "$PID" | grep -v grep
            echo ""
            echo "Để dừng process này, chạy:"
            echo "  sudo kill $PID"
            echo "  hoặc"
            echo "  sudo systemctl stop <service-name>"
        fi
    fi
else
    echo "✓ Port 80 chưa được sử dụng"
fi

echo ""
echo "Port 443:"
if command -v netstat &> /dev/null; then
    PORT443=$(netstat -tuln | grep ':443 ' || echo "")
elif command -v ss &> /dev/null; then
    PORT443=$(ss -tuln | grep ':443 ' || echo "")
elif command -v lsof &> /dev/null; then
    PORT443=$(lsof -i :443 || echo "")
else
    PORT443=""
fi

if [ -n "$PORT443" ]; then
    echo "⚠ Port 443 đang được sử dụng:"
    echo "$PORT443"
    echo ""
    
    # Tìm process ID
    if command -v lsof &> /dev/null; then
        PID=$(lsof -ti :443 | head -1)
        if [ -n "$PID" ]; then
            echo "Process đang sử dụng port 443:"
            ps aux | grep "$PID" | grep -v grep
        fi
    fi
else
    echo "✓ Port 443 chưa được sử dụng"
fi

echo ""
echo "=== Kiểm tra các service web phổ biến ==="

# Kiểm tra Apache
if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
    echo "⚠ Apache đang chạy"
    echo "  Để dừng: sudo systemctl stop apache2 (hoặc httpd)"
elif pgrep -x apache2 > /dev/null 2>&1 || pgrep -x httpd > /dev/null 2>&1; then
    echo "⚠ Apache đang chạy (không qua systemd)"
else
    echo "✓ Apache không chạy"
fi

# Kiểm tra Nginx (không phải container)
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "⚠ Nginx (systemd) đang chạy"
    echo "  Để dừng: sudo systemctl stop nginx"
elif pgrep -x nginx > /dev/null 2>&1 && ! docker ps --format '{{.Names}}' | grep -q nginx; then
    echo "⚠ Nginx đang chạy (không qua systemd)"
else
    echo "✓ Nginx (host) không chạy"
fi

# Kiểm tra Docker containers
echo ""
echo "=== Docker containers đang sử dụng port 80/443 ==="
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "80|443" || echo "Không có container nào sử dụng port 80/443"

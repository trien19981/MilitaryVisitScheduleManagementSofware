#!/bin/bash

# Script để xử lý xung đột port 80

echo "=== Xử lý xung đột port 80 ==="
echo ""

# Tìm process đang sử dụng port 80
echo "Đang tìm process sử dụng port 80..."

if command -v lsof &> /dev/null; then
    PID=$(sudo lsof -ti :80 2>/dev/null | head -1)
    if [ -n "$PID" ]; then
        echo "Tìm thấy process ID: $PID"
        PROCESS_INFO=$(ps aux | grep "^[^ ]* *$PID " | grep -v grep)
        echo "Thông tin process:"
        echo "$PROCESS_INFO"
        echo ""
        
        # Xác định loại service
        if echo "$PROCESS_INFO" | grep -q "apache\|httpd"; then
            SERVICE_NAME="apache2"
            if ! systemctl list-units | grep -q apache2; then
                SERVICE_NAME="httpd"
            fi
            echo "Phát hiện Apache đang chạy!"
            echo ""
            echo "Bạn có muốn dừng Apache để giải phóng port 80 không? (y/n)"
            read -p "Lựa chọn: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Đang dừng Apache..."
                sudo systemctl stop $SERVICE_NAME 2>/dev/null || sudo kill $PID
                echo "✓ Đã dừng Apache"
            else
                echo "Bạn có thể thay đổi port mapping trong docker-compose.yml"
                echo "Thay đổi '80:80' thành '8080:80' hoặc port khác"
                exit 1
            fi
        elif echo "$PROCESS_INFO" | grep -q "nginx"; then
            echo "Phát hiện Nginx đang chạy!"
            echo ""
            echo "Bạn có muốn dừng Nginx để giải phóng port 80 không? (y/n)"
            read -p "Lựa chọn: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Đang dừng Nginx..."
                sudo systemctl stop nginx 2>/dev/null || sudo kill $PID
                echo "✓ Đã dừng Nginx"
            else
                echo "Bạn có thể thay đổi port mapping trong docker-compose.yml"
                echo "Thay đổi '80:80' thành '8080:80' hoặc port khác"
                exit 1
            fi
        else
            echo "Process không xác định đang sử dụng port 80"
            echo ""
            echo "Bạn có muốn dừng process này không? (y/n)"
            read -p "Lựa chọn: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Đang dừng process $PID..."
                sudo kill $PID
                echo "✓ Đã dừng process"
            else
                echo "Bạn có thể thay đổi port mapping trong docker-compose.yml"
                echo "Thay đổi '80:80' thành '8080:80' hoặc port khác"
                exit 1
            fi
        fi
    else
        echo "Không tìm thấy process nào sử dụng port 80"
        echo "Có thể port đã được giải phóng hoặc cần quyền root để kiểm tra"
    fi
elif command -v netstat &> /dev/null; then
    echo "Sử dụng netstat để kiểm tra..."
    sudo netstat -tulpn | grep ':80 '
elif command -v ss &> /dev/null; then
    echo "Sử dụng ss để kiểm tra..."
    sudo ss -tulpn | grep ':80 '
else
    echo "Không tìm thấy công cụ để kiểm tra port (lsof, netstat, ss)"
    echo "Vui lòng cài đặt một trong các công cụ trên"
    exit 1
fi

echo ""
echo "Kiểm tra lại port 80..."
sleep 2

if command -v lsof &> /dev/null; then
    PID=$(sudo lsof -ti :80 2>/dev/null | head -1)
    if [ -z "$PID" ]; then
        echo "✓ Port 80 đã được giải phóng!"
        echo ""
        echo "Bây giờ bạn có thể chạy:"
        echo "  docker compose up -d"
        echo "  hoặc"
        echo "  docker-compose up -d"
    else
        echo "⚠ Port 80 vẫn đang được sử dụng bởi process $PID"
        echo "Vui lòng kiểm tra lại hoặc thay đổi port mapping"
    fi
fi

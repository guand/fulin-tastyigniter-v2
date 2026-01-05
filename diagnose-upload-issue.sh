#!/bin/bash
# Diagnostic script to troubleshoot TastyIgniter media manager upload issues

echo "=========================================="
echo "TastyIgniter Upload Diagnostics"
echo "=========================================="
echo ""

# Check if container is running
if ! docker compose ps tastyigniter-app | grep -q "Up"; then
    echo "❌ ERROR: tastyigniter-app container is not running"
    echo "Start it with: sudo docker compose up -d"
    exit 1
fi

echo "✓ Container is running"
echo ""

echo "1. PHP Upload Configuration"
echo "----------------------------"
docker compose exec tastyigniter-app php -i | grep -E "upload_max_filesize|post_max_size|max_file_uploads|file_uploads"
echo ""

echo "2. Directory Permissions Check"
echo "-------------------------------"
echo "Storage directories:"
docker compose exec tastyigniter-app ls -la /var/www/html/storage/app/ 2>/dev/null
echo ""
echo "Public directories:"
docker compose exec tastyigniter-app ls -la /var/www/html/public/ 2>/dev/null
echo ""
echo "Public uploads directory:"
docker compose exec tastyigniter-app ls -la /var/www/html/public/uploads/ 2>/dev/null
echo ""

echo "3. Ownership Check"
echo "------------------"
echo "Storage app directory owner:"
docker compose exec tastyigniter-app stat -c "%U:%G (%a)" /var/www/html/storage/app/
echo "Storage app media directory owner:"
docker compose exec tastyigniter-app stat -c "%U:%G (%a)" /var/www/html/storage/app/media 2>/dev/null || echo "Directory doesn't exist"
echo "Public uploads directory owner:"
docker compose exec tastyigniter-app stat -c "%U:%G (%a)" /var/www/html/public/uploads 2>/dev/null || echo "Directory doesn't exist"
echo ""

echo "4. Web Server User"
echo "------------------"
docker compose exec tastyigniter-app ps aux | grep apache2 | head -3
echo ""

echo "5. TastyIgniter Filesystem Configuration"
echo "-----------------------------------------"
echo "Checking .env file for filesystem settings:"
docker compose exec tastyigniter-app cat /var/www/html/.env | grep -E "FILESYSTEM|MEDIA|STORAGE|UPLOAD" || echo "No filesystem configuration found in .env"
echo ""

echo "6. Laravel Filesystem Config"
echo "-----------------------------"
echo "Checking config/filesystems.php:"
docker compose exec tastyigniter-app cat /var/www/html/config/filesystems.php 2>/dev/null | grep -A 20 "'disks'" | head -40 || echo "Could not read filesystems config"
echo ""

echo "7. Media Manager Settings"
echo "-------------------------"
echo "Checking if media manager settings exist in database:"
docker compose exec tastyigniter-app php artisan tinker --execute="echo \Igniter\System\Models\Settings::get('media_manager', []);" 2>/dev/null || echo "Could not check media manager settings"
echo ""

echo "8. Recent Application Errors"
echo "----------------------------"
if docker compose exec tastyigniter-app test -f /var/www/html/storage/logs/laravel.log; then
    echo "Last 20 lines of error log:"
    docker compose exec tastyigniter-app tail -n 20 /var/www/html/storage/logs/laravel.log
else
    echo "No log file found"
fi
echo ""

echo "9. Apache Error Log (Recent)"
echo "-----------------------------"
docker compose exec tastyigniter-app tail -n 20 /var/log/apache2/error.log 2>/dev/null || echo "Apache error log not accessible"
echo ""

echo "10. Disk Space Check"
echo "--------------------"
docker compose exec tastyigniter-app df -h /var/www/html
echo ""

echo "11. Test File Creation"
echo "----------------------"
echo "Testing write permissions in storage/app/media:"
docker compose exec tastyigniter-app su -s /bin/bash www-data -c "touch /var/www/html/storage/app/media/test-upload.txt && echo 'test' > /var/www/html/storage/app/media/test-upload.txt" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ SUCCESS: www-data can write to storage/app/media"
    docker compose exec tastyigniter-app rm /var/www/html/storage/app/media/test-upload.txt 2>/dev/null
else
    echo "❌ FAILED: www-data cannot write to storage/app/media"
fi
echo ""

echo "Testing write permissions in public/uploads:"
docker compose exec tastyigniter-app su -s /bin/bash www-data -c "touch /var/www/html/public/uploads/test-upload.txt && echo 'test' > /var/www/html/public/uploads/test-upload.txt" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ SUCCESS: www-data can write to public/uploads"
    docker compose exec tastyigniter-app rm /var/www/html/public/uploads/test-upload.txt 2>/dev/null
else
    echo "❌ FAILED: www-data cannot write to public/uploads"
fi
echo ""

echo "12. SELinux Check (if applicable)"
echo "---------------------------------"
docker compose exec tastyigniter-app getenforce 2>/dev/null || echo "SELinux not enabled or not available"
echo ""

echo "=========================================="
echo "Diagnostics Complete"
echo "=========================================="
echo ""
echo "If you see permission errors above, run:"
echo "  sudo docker compose exec tastyigniter-app chown -R www-data:www-data /var/www/html/storage"
echo "  sudo docker compose exec tastyigniter-app chown -R www-data:www-data /var/www/html/public"
echo "  sudo docker compose exec tastyigniter-app chmod -R 775 /var/www/html/storage"
echo "  sudo docker compose exec tastyigniter-app chmod -R 775 /var/www/html/public"

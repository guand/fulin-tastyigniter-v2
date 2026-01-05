#!/bin/bash
# Script to check TastyIgniter media manager configuration

# Use sudo for docker commands if not in docker group
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
fi

echo "=========================================="
echo "TastyIgniter Media Manager Configuration"
echo "=========================================="
echo ""

# Check if container is running
if ! $DOCKER_CMD compose ps tastyigniter-app | grep -q "Up"; then
    echo "❌ ERROR: tastyigniter-app container is not running"
    echo "Start it with: $DOCKER_CMD compose up -d"
    exit 1
fi

echo "✓ Container is running"
echo ""

echo "1. Media Manager Directory Structure"
echo "-------------------------------------"
echo "Checking if media/uploads directory exists:"
if $DOCKER_CMD compose exec tastyigniter-app test -d /var/www/html/storage/app/public/media; then
    echo "✓ /storage/app/public/media exists"
    $DOCKER_CMD compose exec tastyigniter-app ls -la /var/www/html/storage/app/public/media
else
    echo "❌ /storage/app/public/media does NOT exist"
    echo "Creating it now..."
    $DOCKER_CMD compose exec tastyigniter-app mkdir -p /var/www/html/storage/app/public/media/uploads
    $DOCKER_CMD compose exec tastyigniter-app chown -R www-data:www-data /var/www/html/storage/app/public/media
    $DOCKER_CMD compose exec tastyigniter-app chmod -R 775 /var/www/html/storage/app/public/media
    echo "✓ Created /storage/app/public/media/uploads"
fi
echo ""

echo "2. Media Manager Config File"
echo "-----------------------------"
echo "Checking config/igniter-system.php for media settings:"
$DOCKER_CMD compose exec tastyigniter-app cat /var/www/html/config/igniter-system.php 2>/dev/null | grep -A 30 "media_manager" | head -40 || echo "Could not read config file"
echo ""

echo "3. Media Manager Database Settings"
echo "-----------------------------------"
echo "Checking database for media_manager settings:"
$DOCKER_CMD compose exec tastyigniter-app php artisan tinker --execute="
try {
    \$settings = \Igniter\System\Models\Settings::get('media_manager', []);
    if (empty(\$settings)) {
        echo 'No media_manager settings found in database';
    } else {
        echo 'Media Manager Settings:' . PHP_EOL;
        echo '  max_upload_size: ' . (\$settings['max_upload_size'] ?? 'NOT SET') . PHP_EOL;
        echo '  disk: ' . (\$settings['disk'] ?? 'NOT SET') . PHP_EOL;
        echo '  folder: ' . (\$settings['folder'] ?? 'NOT SET') . PHP_EOL;
        echo '  path: ' . (\$settings['path'] ?? 'NOT SET') . PHP_EOL;
        echo '  enable_uploads: ' . ((\$settings['enable_uploads'] ?? false) ? 'true' : 'false') . PHP_EOL;
    }
} catch (Exception \$e) {
    echo 'Error reading settings: ' . \$e->getMessage();
}
" 2>/dev/null || echo "Could not check database settings"
echo ""

echo "4. PHP Upload Limits"
echo "--------------------"
echo "Current PHP upload limits:"
$DOCKER_CMD compose exec tastyigniter-app php -r "echo 'upload_max_filesize: ' . ini_get('upload_max_filesize') . PHP_EOL;"
$DOCKER_CMD compose exec tastyigniter-app php -r "echo 'post_max_size: ' . ini_get('post_max_size') . PHP_EOL;"
$DOCKER_CMD compose exec tastyigniter-app php -r "echo 'memory_limit: ' . ini_get('memory_limit') . PHP_EOL;"
echo ""

echo "5. Storage Symlink Check"
echo "------------------------"
echo "Checking if public/storage symlink points to storage/app/public:"
if $DOCKER_CMD compose exec tastyigniter-app test -L /var/www/html/public/storage; then
    echo "✓ Symlink exists"
    $DOCKER_CMD compose exec tastyigniter-app ls -la /var/www/html/public/storage
else
    echo "❌ Symlink does NOT exist"
    echo "Creating it now..."
    $DOCKER_CMD compose exec tastyigniter-app php artisan storage:link --force
fi
echo ""

echo "6. Media Upload Path Permissions"
echo "---------------------------------"
echo "Checking permissions on media upload path:"
if $DOCKER_CMD compose exec tastyigniter-app test -d /var/www/html/storage/app/public/media/uploads; then
    $DOCKER_CMD compose exec tastyigniter-app stat -c "Owner: %U:%G, Permissions: %a" /var/www/html/storage/app/public/media/uploads
else
    echo "❌ Upload directory doesn't exist, creating it..."
    $DOCKER_CMD compose exec tastyigniter-app mkdir -p /var/www/html/storage/app/public/media/uploads
    $DOCKER_CMD compose exec tastyigniter-app chown -R www-data:www-data /var/www/html/storage/app/public/media
    $DOCKER_CMD compose exec tastyigniter-app chmod -R 775 /var/www/html/storage/app/public/media
    echo "✓ Created and set permissions"
fi
echo ""

echo "7. Test Write to Media Directory"
echo "---------------------------------"
if $DOCKER_CMD compose exec tastyigniter-app su -s /bin/bash www-data -c "touch /var/www/html/storage/app/public/media/uploads/test.txt 2>/dev/null"; then
    echo "✓ SUCCESS: www-data can write to media/uploads"
    $DOCKER_CMD compose exec tastyigniter-app rm /var/www/html/storage/app/public/media/uploads/test.txt
else
    echo "❌ FAILED: www-data cannot write to media/uploads"
fi
echo ""

echo "=========================================="
echo "Configuration Check Complete"
echo "=========================================="
echo ""
echo "Important Notes:"
echo "1. Default max_upload_size is only 1.5 MB (1500 KB)"
echo "2. If logos are larger, increase this in Admin > Settings > Media Manager"
echo "3. Media files should be stored in: storage/app/public/media/uploads/"
echo "4. Files are accessible via: public/storage/media/uploads/"
echo ""
echo "If max_upload_size is not set or too small:"
echo "  - Go to Admin Panel"
echo "  - Navigate to System > Settings > Media Manager"
echo "  - Increase 'Maximum upload size' (e.g., 10240 for 10 MB)"
echo "  - Save settings"

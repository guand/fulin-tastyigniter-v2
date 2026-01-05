#!/bin/bash
# Script to fix TastyIgniter media manager upload permissions

# Use sudo for docker commands if not in docker group
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
fi

echo "=========================================="
echo "Fixing TastyIgniter Upload Permissions"
echo "=========================================="
echo ""

# Check if container is running
if ! $DOCKER_CMD compose ps tastyigniter-app | grep -q "Up"; then
    echo "❌ ERROR: tastyigniter-app container is not running"
    echo "Start it with: $DOCKER_CMD compose up -d"
    exit 1
fi

echo "Step 1: Ensuring upload directories exist..."
$DOCKER_CMD compose exec tastyigniter-app mkdir -p /var/www/html/storage/app/public
$DOCKER_CMD compose exec tastyigniter-app mkdir -p /var/www/html/storage/app/media
$DOCKER_CMD compose exec tastyigniter-app mkdir -p /var/www/html/storage/app/uploads
$DOCKER_CMD compose exec tastyigniter-app mkdir -p /var/www/html/public/uploads
$DOCKER_CMD compose exec tastyigniter-app mkdir -p /var/www/html/public/uploads/images
$DOCKER_CMD compose exec tastyigniter-app mkdir -p /var/www/html/public/uploads/media
$DOCKER_CMD compose exec tastyigniter-app mkdir -p /var/www/html/public/uploads/temp
echo "✓ Directories created"
echo ""

echo "Step 2: Setting ownership to www-data..."
$DOCKER_CMD compose exec tastyigniter-app chown -R www-data:www-data /var/www/html/storage
$DOCKER_CMD compose exec tastyigniter-app chown -R www-data:www-data /var/www/html/public
echo "✓ Ownership set"
echo ""

echo "Step 3: Setting permissions..."
$DOCKER_CMD compose exec tastyigniter-app chmod -R 775 /var/www/html/storage
$DOCKER_CMD compose exec tastyigniter-app chmod -R 775 /var/www/html/public
echo "✓ Permissions set"
echo ""

echo "Step 4: Recreating storage symlink..."
$DOCKER_CMD compose exec tastyigniter-app rm -f /var/www/html/public/storage
$DOCKER_CMD compose exec tastyigniter-app ln -sf /var/www/html/storage/app/public /var/www/html/public/storage
$DOCKER_CMD compose exec tastyigniter-app php artisan storage:link --force
echo "✓ Symlink created"
echo ""

echo "Step 5: Verifying permissions..."
echo ""
echo "Storage app media:"
$DOCKER_CMD compose exec tastyigniter-app ls -la /var/www/html/storage/app/ | grep media || echo "media directory not found"
echo ""
echo "Public uploads:"
$DOCKER_CMD compose exec tastyigniter-app ls -la /var/www/html/public/ | grep uploads || echo "uploads directory not found"
echo ""
echo "Public storage symlink:"
$DOCKER_CMD compose exec tastyigniter-app ls -la /var/www/html/public/ | grep storage || echo "storage symlink not found"
echo ""

echo "Step 6: Testing write permissions..."
echo ""
echo "Testing storage/app/media write:"
if $DOCKER_CMD compose exec tastyigniter-app su -s /bin/bash www-data -c "touch /var/www/html/storage/app/media/test.txt 2>/dev/null"; then
    echo "✓ SUCCESS: www-data can write to storage/app/media"
    $DOCKER_CMD compose exec tastyigniter-app rm /var/www/html/storage/app/media/test.txt
else
    echo "❌ FAILED: www-data cannot write to storage/app/media"
fi
echo ""

echo "Testing public/uploads write:"
if $DOCKER_CMD compose exec tastyigniter-app su -s /bin/bash www-data -c "touch /var/www/html/public/uploads/test.txt 2>/dev/null"; then
    echo "✓ SUCCESS: www-data can write to public/uploads"
    $DOCKER_CMD compose exec tastyigniter-app rm /var/www/html/public/uploads/test.txt
else
    echo "❌ FAILED: www-data cannot write to public/uploads"
fi
echo ""

echo "=========================================="
echo "Permission Fix Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Try uploading a file in the media manager"
echo "2. If still not working, run: ./diagnose-upload-issue.sh"
echo "3. Check browser console for JavaScript errors"
echo "4. Monitor logs with: ./monitor-logs.sh upload"

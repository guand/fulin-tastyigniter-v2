#!/bin/bash
# Production Server Fix Script for TastyIgniter Media Manager Upload Issues
# Upload this script to your server and run it to diagnose and fix upload problems

echo "=========================================="
echo "TastyIgniter Production Server Fix"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Check media manager configuration"
echo "  2. Verify directory structure"
echo "  3. Fix permissions"
echo "  4. Create missing directories"
echo "  5. Rebuild storage symlinks"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Detect TastyIgniter installation path
if [ -f "artisan" ]; then
    TASTY_PATH="."
elif [ -f "/var/www/html/artisan" ]; then
    TASTY_PATH="/var/www/html"
else
    echo "❌ ERROR: Could not find TastyIgniter installation"
    echo "Please run this script from your TastyIgniter root directory"
    echo "or update TASTY_PATH variable in this script"
    exit 1
fi

cd "$TASTY_PATH" || exit 1
echo "✓ Working directory: $TASTY_PATH"
echo ""

# Determine web server user (www-data, apache, nginx, etc.)
if id "www-data" &>/dev/null; then
    WEB_USER="www-data"
    WEB_GROUP="www-data"
elif id "apache" &>/dev/null; then
    WEB_USER="apache"
    WEB_GROUP="apache"
elif id "nginx" &>/dev/null; then
    WEB_USER="nginx"
    WEB_GROUP="nginx"
else
    WEB_USER="www-data"
    WEB_GROUP="www-data"
    echo "⚠️  Warning: Could not detect web server user, defaulting to www-data"
fi
echo "✓ Web server user: $WEB_USER:$WEB_GROUP"
echo ""

echo "=========================================="
echo "Step 1: Checking Media Manager Settings"
echo "=========================================="
echo ""

echo "Checking database for media_manager settings..."
php artisan tinker --execute="
try {
    \$settings = \Igniter\System\Models\Settings::get('media_manager', []);
    if (empty(\$settings)) {
        echo 'WARNING: No media_manager settings found in database' . PHP_EOL;
        echo 'You will need to configure these in the admin panel' . PHP_EOL;
    } else {
        echo 'Current Media Manager Settings:' . PHP_EOL;
        echo '  max_upload_size: ' . (\$settings['max_upload_size'] ?? 'NOT SET') . ' KB' . PHP_EOL;
        if (isset(\$settings['max_upload_size']) && \$settings['max_upload_size'] <= 1500) {
            echo '  ⚠️  WARNING: Upload size limit is very small (' . \$settings['max_upload_size'] . ' KB)' . PHP_EOL;
            echo '  This is likely too small for most logos!' . PHP_EOL;
            echo '  Recommended: 10240 KB (10 MB) or higher' . PHP_EOL;
        }
        echo '  disk: ' . (\$settings['disk'] ?? 'NOT SET') . PHP_EOL;
        echo '  folder: ' . (\$settings['folder'] ?? 'NOT SET') . PHP_EOL;
        echo '  path: ' . (\$settings['path'] ?? 'NOT SET') . PHP_EOL;
        echo '  enable_uploads: ' . ((\$settings['enable_uploads'] ?? false) ? 'true' : 'false') . PHP_EOL;
    }
} catch (Exception \$e) {
    echo 'Error reading settings: ' . \$e->getMessage() . PHP_EOL;
}
" 2>/dev/null || echo "Could not check database settings (database may not be set up yet)"
echo ""

echo "=========================================="
echo "Step 2: Creating Required Directories"
echo "=========================================="
echo ""

echo "Creating storage directories..."
mkdir -p storage/app/public
mkdir -p storage/app/public/media/uploads
mkdir -p storage/app/media
mkdir -p storage/app/uploads
mkdir -p storage/framework/cache/data
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p storage/logs
echo "✓ Storage directories created"
echo ""

echo "Creating public directories..."
mkdir -p public/uploads
mkdir -p public/uploads/images
mkdir -p public/uploads/media
mkdir -p public/uploads/temp
echo "✓ Public directories created"
echo ""

echo "=========================================="
echo "Step 3: Setting Permissions"
echo "=========================================="
echo ""

echo "Setting ownership to $WEB_USER:$WEB_GROUP..."
chown -R "$WEB_USER":"$WEB_GROUP" storage/
chown -R "$WEB_USER":"$WEB_GROUP" public/
echo "✓ Ownership set"
echo ""

echo "Setting directory permissions..."
chmod -R 775 storage/
chmod -R 775 public/
echo "✓ Permissions set"
echo ""

echo "Setting log file permissions..."
touch storage/logs/laravel.log
chown "$WEB_USER":"$WEB_GROUP" storage/logs/laravel.log
chmod 664 storage/logs/laravel.log
echo "✓ Log file permissions set"
echo ""

echo "=========================================="
echo "Step 4: Storage Symlink"
echo "=========================================="
echo ""

echo "Recreating storage symlink..."
# Remove old symlink if it exists
if [ -L public/storage ]; then
    rm -f public/storage
    echo "  Removed old symlink"
fi

# Remove directory if it exists (shouldn't be a directory)
if [ -d public/storage ] && [ ! -L public/storage ]; then
    echo "  ⚠️  Warning: public/storage is a directory, removing it..."
    rm -rf public/storage
fi

# Create symlink manually
ln -sf ../storage/app/public public/storage
echo "  Created manual symlink"

# Also run Laravel command
php artisan storage:link --force 2>/dev/null || echo "  Laravel storage:link command not available"
echo "✓ Storage symlink created"
echo ""

echo "=========================================="
echo "Step 5: Verification"
echo "=========================================="
echo ""

echo "Directory structure:"
ls -la storage/app/ | grep -E "public|media|uploads" || echo "  Some directories may be missing"
echo ""

echo "Public storage symlink:"
ls -la public/storage 2>/dev/null || echo "  ⚠️  Symlink not found"
echo ""

echo "Testing write permissions:"
if su -s /bin/bash "$WEB_USER" -c "touch storage/app/public/media/uploads/test.txt 2>/dev/null"; then
    echo "  ✓ SUCCESS: $WEB_USER can write to storage/app/public/media/uploads"
    rm -f storage/app/public/media/uploads/test.txt
else
    echo "  ❌ FAILED: $WEB_USER cannot write to storage/app/public/media/uploads"
fi
echo ""

echo "=========================================="
echo "PHP Configuration"
echo "=========================================="
echo ""

echo "Current PHP upload limits:"
php -r "echo 'upload_max_filesize: ' . ini_get('upload_max_filesize') . PHP_EOL;"
php -r "echo 'post_max_size: ' . ini_get('post_max_size') . PHP_EOL;"
php -r "echo 'memory_limit: ' . ini_get('memory_limit') . PHP_EOL;"
echo ""

# Check if limits are too low
UPLOAD_LIMIT=$(php -r "echo ini_get('upload_max_filesize');" | grep -oP '\d+')
if [ "$UPLOAD_LIMIT" -lt 10 ]; then
    echo "⚠️  WARNING: PHP upload_max_filesize is only ${UPLOAD_LIMIT}M"
    echo "This may be too small for larger files"
    echo "Consider increasing it in your php.ini file"
    echo ""
fi

echo "=========================================="
echo "Summary & Next Steps"
echo "=========================================="
echo ""

echo "✓ Directories created and permissions set"
echo "✓ Storage symlink recreated"
echo ""
echo "CRITICAL: You MUST also update settings in the admin panel:"
echo ""
echo "  1. Log into TastyIgniter admin panel"
echo "  2. Go to: System → Settings → Media Manager"
echo "  3. Find 'Maximum upload size (KB)'"
echo "  4. Change from 1500 to 10240 (10 MB) or higher"
echo "  5. Click Save"
echo ""
echo "Without this change, uploads larger than 1.5 MB will still fail!"
echo ""
echo "To test uploads, monitor logs:"
echo "  tail -f storage/logs/laravel.log"
echo "  tail -f /var/log/apache2/error.log  (or nginx)"
echo ""
echo "For the 'Create Folder' input field issue:"
echo "  - Upload mediamanager-fix.js to public/assets/js/"
echo "  - Add script tag to admin layout"
echo "  - See MEDIAMANAGER-FIX-INSTRUCTIONS.md for details"
echo ""
echo "=========================================="
echo "Fix Complete!"
echo "=========================================="

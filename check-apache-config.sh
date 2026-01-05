#!/bin/bash
# Script to verify Apache and .htaccess configuration for TastyIgniter

# Use sudo for docker commands if not in docker group
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
fi

echo "=========================================="
echo "TastyIgniter Apache Configuration Check"
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

echo "1. Apache Modules Check"
echo "------------------------"
echo "Checking if mod_rewrite is enabled:"
$DOCKER_CMD compose exec tastyigniter-app apache2ctl -M | grep rewrite || echo "❌ mod_rewrite NOT enabled"
echo ""
echo "Checking if mod_headers is enabled:"
$DOCKER_CMD compose exec tastyigniter-app apache2ctl -M | grep headers || echo "❌ mod_headers NOT enabled"
echo ""

echo "2. Apache Document Root"
echo "-----------------------"
echo "Current DocumentRoot setting:"
$DOCKER_CMD compose exec tastyigniter-app grep -r "DocumentRoot" /etc/apache2/sites-enabled/ | head -5
echo ""

echo "3. AllowOverride Configuration"
echo "------------------------------"
echo "Checking AllowOverride settings in apache2.conf:"
$DOCKER_CMD compose exec tastyigniter-app grep -A 5 "Directory /var/www" /etc/apache2/apache2.conf | grep -E "Directory|AllowOverride"
echo ""
echo "Checking AllowOverride in sites-enabled:"
$DOCKER_CMD compose exec tastyigniter-app grep -r "AllowOverride" /etc/apache2/sites-enabled/ || echo "No AllowOverride settings in sites-enabled"
echo ""

echo "4. .htaccess File Check"
echo "-----------------------"
echo "Checking if .htaccess exists in public directory:"
if $DOCKER_CMD compose exec tastyigniter-app test -f /var/www/html/public/.htaccess; then
    echo "✓ .htaccess file exists"
    echo ""
    echo "Content of public/.htaccess:"
    $DOCKER_CMD compose exec tastyigniter-app cat /var/www/html/public/.htaccess
else
    echo "❌ .htaccess file NOT found in /var/www/html/public/"
    echo "This is required for TastyIgniter to work properly!"
fi
echo ""

echo "5. .htaccess Permissions"
echo "------------------------"
if $DOCKER_CMD compose exec tastyigniter-app test -f /var/www/html/public/.htaccess; then
    $DOCKER_CMD compose exec tastyigniter-app ls -la /var/www/html/public/.htaccess
else
    echo "❌ .htaccess file not found"
fi
echo ""

echo "6. Apache Error Log (Recent)"
echo "----------------------------"
echo "Recent Apache errors (last 10 lines):"
$DOCKER_CMD compose exec tastyigniter-app tail -n 10 /var/log/apache2/error.log 2>/dev/null || echo "No Apache error log found"
echo ""

echo "7. Test Rewrite Rules"
echo "---------------------"
echo "Testing if Apache can read .htaccess:"
$DOCKER_CMD compose exec tastyigniter-app apache2ctl -t 2>&1 | head -5
echo ""

echo "8. Public Directory Structure"
echo "-----------------------------"
echo "Files in public directory:"
$DOCKER_CMD compose exec tastyigniter-app ls -la /var/www/html/public/ | head -20
echo ""

echo "=========================================="
echo "Configuration Check Complete"
echo "=========================================="
echo ""
echo "Common Issues:"
echo "1. If mod_rewrite is not enabled, rebuild the container"
echo "2. If .htaccess is missing, copy it from the TastyIgniter repository"
echo "3. If AllowOverride is set to 'None', it should be 'All'"
echo "4. Make sure .htaccess has proper permissions (644)"

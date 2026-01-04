#!/bin/bash
# Diagnostic script to check TastyIgniter media paths

echo "=== Checking TastyIgniter Media Manager Paths ==="
echo ""

echo "1. Storage directories:"
docker compose exec tastyigniter-app ls -la /var/www/html/storage/app/
echo ""

echo "2. Public directories:"
docker compose exec tastyigniter-app ls -la /var/www/html/public/
echo ""

echo "3. Public uploads directories:"
docker compose exec tastyigniter-app ls -la /var/www/html/public/uploads/
echo ""

echo "4. Public storage symlink:"
docker compose exec tastyigniter-app ls -la /var/www/html/public/storage
echo ""

echo "5. Directory permissions (numeric):"
docker compose exec tastyigniter-app stat -c "%a %n" /var/www/html/storage/app/media
docker compose exec tastyigniter-app stat -c "%a %n" /var/www/html/public/uploads
echo ""

echo "6. Ownership:"
docker compose exec tastyigniter-app ls -ln /var/www/html/storage/app/ | head -5
echo ""

echo "7. Check if www-data user exists and its ID:"
docker compose exec tastyigniter-app id www-data
echo ""

echo "8. Current PHP/Apache user:"
docker compose exec tastyigniter-app ps aux | grep apache2 | head -3
echo ""

echo "9. Laravel storage symlink status:"
docker compose exec tastyigniter-app php artisan storage:link --force
echo ""

echo "10. Environment variables related to filesystem:"
docker compose exec tastyigniter-app cat /var/www/html/.env | grep -E "FILESYSTEM|MEDIA|STORAGE" || echo "No filesystem config found"
echo ""

echo "=== End of diagnostics ==="

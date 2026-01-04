#!/bin/bash
set -e

cd /var/www/html

# Environment variables with defaults
DOMAIN="${DOMAIN:-localhost}"
EMAIL="${EMAIL:-admin@localhost}"
ENABLE_SSL="${ENABLE_SSL:-false}"

# Create necessary storage subdirectories if they don't exist
mkdir -p /var/www/html/storage/app/public
mkdir -p /var/www/html/storage/app/media
mkdir -p /var/www/html/storage/app/uploads
mkdir -p /var/www/html/storage/framework/cache/data
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/storage/temp
mkdir -p /var/www/html/storage/system/combiner
mkdir -p /var/www/html/storage/system/cache

# Create symbolic link from public/storage to storage/app/public if it doesn't exist
if [ ! -L /var/www/html/public/storage ]; then
    ln -sf /var/www/html/storage/app/public /var/www/html/public/storage
fi

# Fix permissions for storage and public directories
chown -R www-data:www-data /var/www/html/storage
chown -R www-data:www-data /var/www/html/public
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/public

# Fix permissions for Composer cache directory
chown -R www-data:www-data /var/www/.composer
chmod -R 775 /var/www/.composer

# Create .env file if it doesn't exist
if [ ! -f '/var/www/html/.env' ]; then
	if [ -f '/var/www/html/.env.example' ]; then
		cp /var/www/html/.env.example /var/www/html/.env
	else
		# Create minimal .env file with actual environment values
		cat > /var/www/html/.env << EOF
APP_NAME=TastyIgniter
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=${APP_URL:-http://localhost}

DB_CONNECTION=${DB_CONNECTION:-mysql}
DB_HOST=${DB_HOST:-tastyigniter-database}
DB_PORT=${DB_PORT:-3306}
DB_DATABASE=${DB_DATABASE:-tastyigniter}
DB_USERNAME=${DB_USERNAME:-tastyigniter}
DB_PASSWORD=${DB_PASSWORD:-tastyigniter}

CACHE_DRIVER=${CACHE_DRIVER:-file}
SESSION_DRIVER=file
QUEUE_CONNECTION=sync

REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PASSWORD=null
REDIS_PORT=6379
EOF
	fi
	
	chown www-data:www-data /var/www/html/.env
fi

# Check if already installed by looking for APP_KEY in .env
if grep -q "^APP_KEY=$" /var/www/html/.env 2>/dev/null; then
	# Generate application key
	php artisan key:generate --force
	
	# Wait for database to be ready
	echo "Waiting for database..."
	sleep 5
	
	# Run TastyIgniter installation
	php artisan igniter:install --no-interaction

	# Clear cache and regenerate assets after installation
	php artisan cache:clear
	php artisan view:clear

	# set permissions after installation for newly created files
	chown -R www-data:www-data /var/www/html/storage
	chown -R www-data:www-data /var/www/html/public
	chmod -R 775 /var/www/html/storage
	chmod -R 775 /var/www/html/public
fi

# Ensure storage directories exist and have correct permissions on every container start
mkdir -p /var/www/html/storage/app/public
mkdir -p /var/www/html/storage/app/media
mkdir -p /var/www/html/storage/app/uploads
mkdir -p /var/www/html/storage/framework/cache/data
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/storage/temp
mkdir -p /var/www/html/storage/system/combiner
mkdir -p /var/www/html/storage/system/cache

# Ensure symbolic link exists
if [ ! -L /var/www/html/public/storage ]; then
    ln -sf /var/www/html/storage/app/public /var/www/html/public/storage
fi

chown -R www-data:www-data /var/www/html/storage
chown -R www-data:www-data /var/www/html/public
chown -R www-data:www-data /var/www/.composer
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/public
chmod -R 775 /var/www/.composer

# Configure Apache SSL if enabled
if [ "$ENABLE_SSL" = "true" ]; then
    echo "SSL is enabled. Configuring Apache for HTTPS..."

    # Check if SSL certificate exists
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
        echo "SSL certificates found for $DOMAIN"

        # Generate Apache SSL config from template using sed
        sed -e "s|\${DOMAIN}|${DOMAIN}|g" \
            -e "s|\${EMAIL}|${EMAIL}|g" \
            -e "s|\${APACHE_DOCUMENT_ROOT}|${APACHE_DOCUMENT_ROOT}|g" \
            /etc/apache2/apache-ssl.conf.template > /etc/apache2/sites-available/000-default-ssl.conf

        # Enable SSL site
        a2ensite 000-default-ssl.conf

        # Create webroot directory for certbot challenges
        mkdir -p /var/www/certbot/.well-known/acme-challenge
        chown -R www-data:www-data /var/www/certbot

        echo "Apache configured for HTTPS on $DOMAIN"
        echo "Your site will be accessible at: https://$DOMAIN"
    else
        echo "ERROR: SSL is enabled but certificates not found!"
        echo "Expected certificates at: /etc/letsencrypt/live/$DOMAIN/"
        echo ""
        echo "To obtain SSL certificates, run:"
        echo "  docker-compose exec tastyigniter-app init-ssl.sh"
        echo ""
        echo "Starting Apache without SSL for now..."
    fi
else
    echo "SSL is disabled. Running on HTTP only."
    echo "To enable SSL:"
    echo "  1. Set your domain to point to this server"
    echo "  2. Run: docker-compose exec tastyigniter-app init-ssl.sh"
    echo "  3. Set ENABLE_SSL=true in your .env file"
    echo "  4. Restart: docker-compose restart tastyigniter-app"

    # Configure HTTP-only virtualhost with certbot support
    mkdir -p /var/www/certbot/.well-known/acme-challenge
    chown -R www-data:www-data /var/www/certbot
fi

# Start cron for certificate renewal (if SSL enabled)
if [ "$ENABLE_SSL" = "true" ]; then
    echo "Starting cron for certificate auto-renewal..."
    service cron start
fi

exec "$@"

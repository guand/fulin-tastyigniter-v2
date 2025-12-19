#!/bin/bash
set -e

# This script initializes SSL certificates using certbot
# It should be run manually after the container is up and accessible from the internet

DOMAIN="${DOMAIN:-localhost}"
EMAIL="${EMAIL:-admin@localhost}"

echo "=========================================="
echo "SSL Certificate Initialization Script"
echo "=========================================="
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo ""

if [ "$DOMAIN" = "localhost" ] || [ "$DOMAIN" = "" ]; then
    echo "ERROR: DOMAIN is not set or is set to localhost"
    echo "Please set the DOMAIN environment variable to your actual domain name"
    echo "Example: export DOMAIN=example.com"
    exit 1
fi

if [ "$EMAIL" = "admin@localhost" ] || [ "$EMAIL" = "" ]; then
    echo "WARNING: EMAIL is set to default value"
    echo "It's recommended to use a valid email address for certificate notifications"
fi

echo "This script will obtain an SSL certificate from Let's Encrypt"
echo "Make sure:"
echo "  1. Both $DOMAIN and www.$DOMAIN point to this server's public IP"
echo "  2. Ports 80 and 443 are accessible from the internet"
echo "  3. Apache is running and responding to HTTP requests"
echo ""
read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Obtaining SSL certificate..."

# Run certbot to obtain certificate for both non-www and www versions
certbot certonly \
    --apache \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --domains "$DOMAIN,www.$DOMAIN" \
    --keep-until-expiring

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "SUCCESS! SSL certificate obtained"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Stop the container: docker-compose down"
    echo "  2. Set ENABLE_SSL=true in your .env file"
    echo "  3. Start the container: docker-compose up -d"
    echo ""
    echo "Your site will be accessible at: https://www.$DOMAIN"
    echo "Requests to https://$DOMAIN will redirect to https://www.$DOMAIN"
else
    echo ""
    echo "=========================================="
    echo "ERROR: Failed to obtain SSL certificate"
    echo "=========================================="
    echo ""
    echo "Common issues:"
    echo "  - Domain doesn't point to this server"
    echo "  - Firewall blocking ports 80 or 443"
    echo "  - Apache not running or misconfigured"
    echo ""
    exit 1
fi

# Setup auto-renewal cron job
echo "Setting up automatic certificate renewal..."
CRON_JOB="0 3 * * * certbot renew --quiet --post-hook 'apachectl graceful'"
(crontab -l 2>/dev/null | grep -v "certbot renew"; echo "$CRON_JOB") | crontab -

echo "Auto-renewal configured to run daily at 3 AM"
echo ""

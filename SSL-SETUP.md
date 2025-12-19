# SSL Setup Guide for TastyIgniter

This guide explains how to enable SSL/HTTPS for your TastyIgniter installation using Let's Encrypt and certbot.

## Prerequisites

Before enabling SSL, ensure:

1. You have a registered domain name
2. Your domain's DNS A record points to your server's public IP address
3. Ports 80 and 443 are open and accessible from the internet
4. Your server is publicly accessible (not behind a firewall that blocks these ports)

## Quick Start

### Step 1: Configure Environment Variables

Create a `.env` file in the project root (or copy from `.env.example`):

```bash
cp .env.example .env
```

Edit the `.env` file and set:

```bash
DOMAIN=yourdomain.com
EMAIL=your-email@example.com
ENABLE_SSL=false  # Keep this false initially
APP_URL=http://yourdomain.com
```

Replace:
- `yourdomain.com` with your actual domain
- `your-email@example.com` with a valid email address (for certificate expiry notifications)

### Step 2: Start the Application

Start your Docker containers:

```bash
docker-compose up -d
```

Wait for the application to fully start. Check logs if needed:

```bash
docker-compose logs -f tastyigniter-app
```

### Step 3: Verify HTTP Access

Make sure your site is accessible via HTTP:

```bash
curl http://yourdomain.com
```

Or visit `http://yourdomain.com` in your browser.

### Step 4: Obtain SSL Certificate

Run the SSL initialization script inside the container:

```bash
docker-compose exec tastyigniter-app init-ssl.sh
```

This script will:
- Validate your domain and email settings
- Use certbot to obtain a free SSL certificate from Let's Encrypt
- Set up automatic certificate renewal

Follow the prompts. If successful, you'll see a success message.

### Step 5: Enable SSL

After successfully obtaining the certificate:

1. Edit your `.env` file:
   ```bash
   ENABLE_SSL=true
   APP_URL=https://yourdomain.com
   ```

2. Restart the container:
   ```bash
   docker-compose restart tastyigniter-app
   ```

3. Your site should now be accessible via HTTPS:
   ```
   https://yourdomain.com
   ```

## Port Mapping

The docker-compose configuration maps:
- Port 80 → Container Port 80 (HTTP)
- Port 443 → Container Port 443 (HTTPS)

The application is accessible directly on standard HTTP/HTTPS ports.

## Certificate Renewal

Certificates from Let's Encrypt are valid for 90 days. The setup includes automatic renewal:

- A cron job runs daily at 3 AM to check and renew certificates if needed
- Certificates are renewed automatically when they have 30 days or less remaining
- Apache is gracefully reloaded after renewal to use the new certificates

### Manual Renewal

To manually renew certificates:

```bash
docker-compose exec tastyigniter-app certbot renew
docker-compose exec tastyigniter-app apachectl graceful
```

### Check Certificate Status

```bash
docker-compose exec tastyigniter-app certbot certificates
```

## Troubleshooting

### Certificate Request Failed

**Problem**: `init-ssl.sh` fails to obtain a certificate

**Common causes**:
1. Domain doesn't point to your server
   - Solution: Check DNS settings with `dig yourdomain.com` or `nslookup yourdomain.com`

2. Ports 80/443 blocked by firewall
   - Solution: Open ports in your firewall (ufw, iptables, cloud provider security groups)

3. Apache not responding
   - Solution: Check Apache logs: `docker-compose logs tastyigniter-app`

### Certificate Files Not Found

**Problem**: "SSL certificates not found" error

**Solution**:
```bash
# Check if certificates exist
docker-compose exec tastyigniter-app ls -la /etc/letsencrypt/live/

# If missing, run init-ssl.sh again
docker-compose exec tastyigniter-app init-ssl.sh
```

### Mixed Content Warnings

**Problem**: Browser shows "mixed content" warnings on HTTPS site

**Solution**: Update your APP_URL in `.env` to use `https://`:
```bash
APP_URL=https://yourdomain.com
```

Then rebuild and restart:
```bash
docker-compose down
docker-compose up -d --build
```

### Certificate Renewal Fails

**Problem**: Automatic renewal is not working

**Solution**:
```bash
# Test renewal in dry-run mode
docker-compose exec tastyigniter-app certbot renew --dry-run

# Check cron is running
docker-compose exec tastyigniter-app service cron status

# Manually renew if needed
docker-compose exec tastyigniter-app certbot renew --force-renewal
```

## SSL Configuration Details

### Apache Modules Enabled
- `mod_ssl` - SSL/TLS support
- `mod_rewrite` - URL rewriting and HTTP to HTTPS redirects
- `mod_headers` - HTTP header manipulation

### SSL/TLS Configuration

The Apache SSL configuration uses modern security settings:
- **Protocols**: TLS 1.2 and TLS 1.3 only (SSLv3, TLS 1.0, and TLS 1.1 disabled)
- **Cipher Suites**: Modern, secure ciphers only
- **HSTS**: Optional (commented out by default)

To enable HSTS (HTTP Strict Transport Security), edit `apache-ssl.conf.template` and uncomment:
```apache
Header always set Strict-Transport-Security "max-age=63072000"
```

Then rebuild and restart.

### Certificate Locations

Inside the container:
- Certificates: `/etc/letsencrypt/live/yourdomain.com/`
- Fullchain: `/etc/letsencrypt/live/yourdomain.com/fullchain.pem`
- Private key: `/etc/letsencrypt/live/yourdomain.com/privkey.pem`

These are stored in the Docker volume `letsencrypt` and persist across container restarts.

## Advanced Configuration

### Multiple Domains

To use multiple domains or subdomains:

1. Obtain certificates for all domains:
   ```bash
   docker-compose exec tastyigniter-app certbot certonly \
     --apache \
     --non-interactive \
     --agree-tos \
     --email your-email@example.com \
     --domains yourdomain.com,www.yourdomain.com,subdomain.yourdomain.com
   ```

2. Update `apache-ssl.conf.template` to include ServerAlias directives

### Custom SSL Certificates

If you have your own SSL certificates (not from Let's Encrypt):

1. Copy your certificates to the `letsencrypt` volume
2. Update paths in `apache-ssl.conf.template`
3. Set `ENABLE_SSL=true` and restart

### Testing SSL Configuration

Use SSL Labs to test your SSL configuration:
https://www.ssllabs.com/ssltest/analyze.html?d=yourdomain.com

## Security Recommendations

1. Keep `ENABLE_SSL=false` until certificates are obtained
2. Use a valid email address for certificate notifications
3. Enable HSTS after confirming everything works
4. Regularly update your Docker images
5. Monitor certificate expiry dates
6. Keep ports 80 and 443 open (80 needed for renewals)

## Support

For issues:
- Check Docker logs: `docker-compose logs tastyigniter-app`
- Verify Apache config: `docker-compose exec tastyigniter-app apachectl -t`
- Test SSL: `docker-compose exec tastyigniter-app openssl s_client -connect localhost:443`

For Let's Encrypt issues, see: https://letsencrypt.org/docs/

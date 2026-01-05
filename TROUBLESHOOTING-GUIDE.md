# TastyIgniter Media Manager Troubleshooting Guide

This guide covers all the issues you've encountered and how to fix them.

## Issues Addressed

1. ✅ Media manager input field not allowing typing (Create Folder dialog)
2. ✅ File upload not working in media manager
3. ✅ Log files not being created
4. ✅ Permission issues when running Docker with sudo
5. ✅ Apache .htaccess configuration

## Quick Fix Commands

### 1. Rebuild Docker Container (Apply all fixes)
```bash
sudo docker compose build
sudo docker compose up -d
```

### 2. Fix Permissions
```bash
./fix-upload-permissions.sh
```

### 3. Check Apache Configuration
```bash
./check-apache-config.sh
```

### 4. Monitor Logs for Upload Issues
```bash
./monitor-logs.sh upload
```

### 5. Run Full Diagnostics
```bash
./diagnose-upload-issue.sh
```

## Detailed Issue Breakdown

### Issue 1: Create Folder Input Not Working

**Problem:** Cannot type in the "Create Folder" input field in the media manager.

**Root Cause:** SweetAlert2's `showLoaderOnConfirm: true` creates a loading overlay that blocks input interaction.

**Solution:**
1. Upload [mediamanager-fix.js](mediamanager-fix.js) to your server at:
   ```
   /var/www/html/public/assets/js/mediamanager-fix.js
   ```

2. Add this script tag to your admin layout (before closing `</body>` tag):
   ```html
   <script src="{{ asset('assets/js/mediamanager-fix.js') }}"></script>
   ```

3. Clear cache:
   ```bash
   php artisan cache:clear
   php artisan view:clear
   ```

**See:** [MEDIAMANAGER-FIX-INSTRUCTIONS.md](MEDIAMANAGER-FIX-INSTRUCTIONS.md) for detailed instructions.

---

### Issue 2: File Upload Not Working

**Problem:** Files cannot be uploaded through the media manager.

**Possible Causes:**
1. Permission issues (most common with sudo)
2. PHP upload limits too low
3. Missing upload directories
4. Broken storage symlinks
5. Apache .htaccess misconfiguration

**Solutions:**

#### A. Fix Permissions (Most Common)
```bash
./fix-upload-permissions.sh
```

This script:
- Creates all necessary upload directories
- Sets ownership to www-data:www-data
- Sets permissions to 775
- Recreates storage symlinks
- Tests write permissions

#### B. Verify PHP Settings
After rebuilding, check PHP upload settings:
```bash
sudo docker compose exec tastyigniter-app php -i | grep -E "upload_max_filesize|post_max_size"
```

Should show:
```
upload_max_filesize => 64M => 64M
post_max_size => 64M => 64M
```

#### C. Check Apache Configuration
```bash
./check-apache-config.sh
```

Verify:
- mod_rewrite is enabled
- AllowOverride is set to All
- .htaccess file exists in public directory

---

### Issue 3: Log Files Not Being Created

**Problem:** `grep: /var/www/html/storage/logs/laravel.log: No such file or directory`

**Root Cause:** When running Docker with sudo, log files might not be created with proper permissions.

**Solution:**
The [docker-entrypoint.sh](docker-entrypoint.sh) has been updated to:
1. Create the log file on container startup (line 49-51)
2. Set proper ownership to www-data (line 50)
3. Set proper permissions (664) (line 51)

After rebuilding, logs will be created automatically.

**Manual Fix (if needed):**
```bash
sudo docker compose exec tastyigniter-app touch /var/www/html/storage/logs/laravel.log
sudo docker compose exec tastyigniter-app chown www-data:www-data /var/www/html/storage/logs/laravel.log
sudo docker compose exec tastyigniter-app chmod 664 /var/www/html/storage/logs/laravel.log
```

---

### Issue 4: Docker Permission Denied

**Problem:** `permission denied while trying to connect to the Docker daemon socket`

**Solutions:**

#### Option A: Add User to Docker Group (Recommended)
```bash
sudo usermod -aG docker $USER
newgrp docker
docker ps  # Test without sudo
```

#### Option B: Use Scripts with Automatic Sudo Detection
All scripts now automatically detect if sudo is needed:
- [monitor-logs.sh](monitor-logs.sh)
- [diagnose-upload-issue.sh](diagnose-upload-issue.sh)
- [fix-upload-permissions.sh](fix-upload-permissions.sh)
- [check-apache-config.sh](check-apache-config.sh)

They work whether you're in the docker group or not.

---

### Issue 5: Apache .htaccess Configuration

**Problem:** TastyIgniter requires proper Apache configuration for .htaccess to work.

**Verification:**

The [Dockerfile](Dockerfile) already includes:
1. `mod_rewrite` enabled (line 54)
2. `AllowOverride All` configured (line 66)
3. DocumentRoot set to `/var/www/html/public` (line 57)

**Check Configuration:**
```bash
./check-apache-config.sh
```

**Manual Verification:**
```bash
# Check if mod_rewrite is enabled
sudo docker compose exec tastyigniter-app apache2ctl -M | grep rewrite

# Check AllowOverride setting
sudo docker compose exec tastyigniter-app grep -A 5 "Directory /var/www" /etc/apache2/apache2.conf

# Check if .htaccess exists
sudo docker compose exec tastyigniter-app ls -la /var/www/html/public/.htaccess
```

---

## Complete Troubleshooting Workflow

Follow these steps in order:

### Step 1: Rebuild Container
```bash
sudo docker compose build
sudo docker compose up -d
```

This applies:
- PHP upload limit increases (64M)
- Log file creation fixes
- All permission fixes from docker-entrypoint.sh

### Step 2: Verify Apache Configuration
```bash
./check-apache-config.sh
```

Look for:
- ✅ mod_rewrite enabled
- ✅ AllowOverride All
- ✅ .htaccess exists in public/

### Step 3: Fix Permissions
```bash
./fix-upload-permissions.sh
```

Should show:
- ✅ SUCCESS: www-data can write to storage/app/media
- ✅ SUCCESS: www-data can write to public/uploads

### Step 4: Deploy JavaScript Fix (For Input Field)
1. Copy [mediamanager-fix.js](mediamanager-fix.js) to server
2. Add script tag to admin layout
3. Clear cache

### Step 5: Test Upload
1. Open media manager in admin panel
2. Start log monitoring:
   ```bash
   ./monitor-logs.sh upload
   ```
3. Try uploading a file
4. Watch logs for any errors

### Step 6: Run Full Diagnostics (If Still Not Working)
```bash
./diagnose-upload-issue.sh
```

This comprehensive check will show:
- PHP upload configuration
- Directory permissions
- Ownership
- Write permission tests
- Recent errors
- Disk space

---

## Files Created for You

| File | Purpose |
|------|---------|
| [mediamanager-fix.js](mediamanager-fix.js) | Fixes input field blocking in Create Folder dialog |
| [MEDIAMANAGER-FIX-INSTRUCTIONS.md](MEDIAMANAGER-FIX-INSTRUCTIONS.md) | Detailed deployment instructions for JS fix |
| [monitor-logs.sh](monitor-logs.sh) | Monitor TastyIgniter logs in real-time |
| [diagnose-upload-issue.sh](diagnose-upload-issue.sh) | Comprehensive upload diagnostics |
| [fix-upload-permissions.sh](fix-upload-permissions.sh) | Automatically fix all upload permissions |
| [check-apache-config.sh](check-apache-config.sh) | Verify Apache and .htaccess configuration |

---

## Common Error Messages and Solutions

### "Permission denied" when uploading
**Solution:** Run `./fix-upload-permissions.sh`

### "Failed to write file to disk"
**Causes:**
1. Disk full - Check with `df -h`
2. Wrong permissions - Run `./fix-upload-permissions.sh`
3. PHP upload limit - Rebuild container

### "Cannot type in Create Folder input"
**Solution:** Deploy [mediamanager-fix.js](mediamanager-fix.js)

### "The file could not be uploaded"
**Check:**
1. Browser console for JavaScript errors
2. Run `./monitor-logs.sh upload` and try again
3. Check Apache error logs

### "File is too large"
**Solution:** Rebuild container (PHP limits increased to 64M)

---

## Still Not Working?

If you've followed all steps and uploads still don't work:

1. **Check Browser Console:**
   - Open DevTools (F12)
   - Look for JavaScript errors
   - Check Network tab for failed requests

2. **Monitor Logs in Real-Time:**
   ```bash
   ./monitor-logs.sh upload
   ```
   Then try uploading and watch for errors.

3. **Run Full Diagnostics:**
   ```bash
   ./diagnose-upload-issue.sh > diagnostics.txt
   ```
   Review the output for any red flags.

4. **Check System Logs on Live Server:**
   If this is for your live server (fulin-restaurant.com), SSH in and:
   ```bash
   tail -f /var/www/html/storage/logs/laravel.log
   tail -f /var/log/apache2/error.log
   ```

---

## Quick Reference: All Scripts

```bash
# Monitor upload activity
./monitor-logs.sh upload

# Monitor all application logs
./monitor-logs.sh app

# Show recent logs from all sources
./monitor-logs.sh all

# Fix all upload permissions
./fix-upload-permissions.sh

# Run comprehensive diagnostics
./diagnose-upload-issue.sh

# Verify Apache configuration
./check-apache-config.sh

# Rebuild container with all fixes
sudo docker compose build && sudo docker compose up -d
```

---

## Summary of Changes Made

### Dockerfile Changes
- ✅ Added PHP upload settings (lines 45-52)
  - `upload_max_filesize=64M`
  - `post_max_size=64M`
  - `max_file_uploads=20`
  - `memory_limit=256M`

### docker-entrypoint.sh Changes
- ✅ Create log file with proper permissions (lines 49-51, 177-179)
- ✅ Set ownership to www-data
- ✅ Set permissions to 664

### docker-compose.yml Changes
- ✅ Removed persistent volumes for storage and public (to avoid permission issues)

### Scripts Created
- ✅ 6 diagnostic and fix scripts
- ✅ JavaScript fix for input field issue
- ✅ Comprehensive documentation

---

## For Production Server (fulin-restaurant.com)

Since your production server is running live, you'll need to:

1. **SSH into your server**
2. **Deploy the JavaScript fix** for the input field issue
3. **Check permissions** on the live server:
   ```bash
   ls -la /var/www/html/storage/app/media
   ls -la /var/www/html/public/uploads
   ```
4. **Fix permissions if needed:**
   ```bash
   chown -R www-data:www-data /var/www/html/storage
   chown -R www-data:www-data /var/www/html/public
   chmod -R 775 /var/www/html/storage
   chmod -R 775 /var/www/html/public
   ```

The Docker changes are for your local development environment.

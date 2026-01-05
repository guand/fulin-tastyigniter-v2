# Logo Upload Issue - Root Causes and Solutions

## Critical Finding: Default Upload Size Limit

**The primary cause of logo upload failures is likely the TastyIgniter media manager's default upload size limit of only 1.5 MB (1500 KB).**

Most high-quality logos are larger than this, especially if they're high-resolution images.

---

## Root Causes Identified

### 1. **Media Manager Upload Size Limit (Most Likely)**
- **Default**: 1.5 MB (1500 KB)
- **Location**: Admin Panel > System > Settings > Media Manager
- **Symptom**: Files larger than 1.5 MB fail silently or with size error

### 2. **Missing Media Directory Structure**
- **Required Path**: `storage/app/public/media/uploads/`
- **Symptom**: Upload fails because directory doesn't exist
- **Fix**: Now auto-created by docker-entrypoint.sh

### 3. **Incorrect Storage Disk Configuration**
- **Expected**: Files should go to `storage/app/public/media/uploads/`
- **Via Symlink**: Accessible at `public/storage/media/uploads/`
- **Issue**: If symlink is broken, uploads fail

### 4. **Permission Issues**
- **Required Owner**: www-data:www-data
- **Required Permissions**: 775
- **Symptom**: "Permission denied" or "Failed to write file"

### 5. **PHP Upload Limits**
- **Old Limits**: Default PHP limits might be too low
- **New Limits** (after rebuild): 64M upload_max_filesize and post_max_size
- **Note**: TastyIgniter's media manager has its OWN limit separate from PHP

---

## Complete Fix Procedure

### Step 1: Check Current Configuration
```bash
./check-media-config.sh
```

This will show you:
- Current media manager upload size limit
- Whether the media/uploads directory exists
- PHP upload limits
- Storage symlink status
- Write permissions

### Step 2: Rebuild Container (Applies PHP Limit Fixes)
```bash
sudo docker compose build
sudo docker compose up -d
```

This ensures:
- PHP limits are set to 64M
- Media directory structure is created
- Proper permissions are set

### Step 3: Fix Permissions
```bash
./fix-upload-permissions.sh
```

### Step 4: Increase Media Manager Upload Limit

**CRITICAL**: You must also increase the limit in TastyIgniter's admin panel:

1. Log into TastyIgniter Admin Panel
2. Go to **System** → **Settings** → **Media Manager**
3. Find **"Maximum upload size (KB)"**
4. Change from `1500` (1.5 MB) to a larger value:
   - For most logos: `10240` (10 MB)
   - For very large files: `20480` (20 MB)
5. Click **Save**

### Step 5: Test Upload
```bash
./monitor-logs.sh upload
```

Then try uploading a logo and watch for errors in the logs.

---

## Understanding TastyIgniter's Two-Level Upload Limits

TastyIgniter has **TWO separate upload size limits** that BOTH must be satisfied:

### Level 1: PHP Limits (Server-Level)
```
upload_max_filesize = 64M
post_max_size = 64M
```
✅ **Fixed by rebuilding the Docker container**

### Level 2: Media Manager Limits (Application-Level)
```
max_upload_size = 1500 KB (1.5 MB) ← DEFAULT
```
❌ **Must be changed in Admin Panel > Settings > Media Manager**

**A file must be smaller than BOTH limits to upload successfully.**

---

## File Storage Paths

Understanding where files actually go:

| What | Path |
|------|------|
| **Physical Storage** | `/var/www/html/storage/app/public/media/uploads/` |
| **Public Access** | `/var/www/html/public/storage/media/uploads/` (symlink) |
| **URL** | `https://your-site.com/storage/media/uploads/filename.png` |

The symlink is created by:
```bash
php artisan storage:link
```

This is automatically done in docker-entrypoint.sh, but can be manually run if needed.

---

## Diagnostic Commands

### Check if media directory exists
```bash
sudo docker compose exec tastyigniter-app ls -la /var/www/html/storage/app/public/media/uploads/
```

### Check media manager settings in database
```bash
sudo docker compose exec tastyigniter-app php artisan tinker --execute="print_r(\Igniter\System\Models\Settings::get('media_manager'));"
```

### Check PHP upload limits
```bash
sudo docker compose exec tastyigniter-app php -i | grep -E "upload_max_filesize|post_max_size"
```

### Test write permissions
```bash
sudo docker compose exec tastyigniter-app su -s /bin/bash www-data -c "touch /var/www/html/storage/app/public/media/uploads/test.txt"
```

---

## Common Error Messages and Solutions

### "The file is too large"
**Cause**: File exceeds media manager's `max_upload_size` setting
**Solution**: Increase the limit in Admin Panel > Settings > Media Manager

### "Failed to write file to disk"
**Cause**: Permission issue or disk full
**Solution**:
1. Run `./fix-upload-permissions.sh`
2. Check disk space: `df -h`

### "File uploaded successfully but not appearing"
**Cause**: Broken storage symlink
**Solution**: Run `php artisan storage:link --force`

### No error message, just fails silently
**Causes**:
1. JavaScript error - Check browser console
2. File size limit - Check media manager settings
3. Network timeout - Check Apache/PHP timeout settings

---

## For Production Server (fulin-restaurant.com)

Since you're having issues on the live server, here's what to check:

### 1. SSH into your server
```bash
ssh user@fulin-restaurant.com
```

### 2. Check media manager settings
```bash
cd /var/www/html  # or wherever TastyIgniter is installed
php artisan tinker --execute="print_r(\Igniter\System\Models\Settings::get('media_manager'));"
```

Look for `max_upload_size` - if it's `1500` or not set, that's your problem.

### 3. Increase via Admin Panel
- Go to Admin > Settings > Media Manager
- Increase "Maximum upload size (KB)" to 10240 or higher
- Save

### 4. Check directory exists and permissions
```bash
ls -la storage/app/public/media/uploads/
# Should show: drwxrwxr-x www-data www-data

# If wrong, fix it:
mkdir -p storage/app/public/media/uploads
chown -R www-data:www-data storage/app/public/media
chmod -R 775 storage/app/public/media
```

### 5. Check storage symlink
```bash
ls -la public/storage
# Should show: storage -> ../storage/app/public

# If broken, recreate:
php artisan storage:link --force
```

### 6. Monitor logs while testing
```bash
tail -f storage/logs/laravel.log &
tail -f /var/log/apache2/error.log &
# Then try uploading
```

---

## Updated Files

### docker-entrypoint.sh
✅ Now creates `/storage/app/public/media/uploads/` directory automatically (lines 13, 134)

### check-media-config.sh
✅ New script to diagnose media manager configuration issues

### fix-upload-permissions.sh
✅ Updated to also create media/uploads directory

---

## Quick Fix Checklist

- [ ] Rebuild Docker container: `sudo docker compose build && sudo docker compose up -d`
- [ ] Run permission fix: `./fix-upload-permissions.sh`
- [ ] Check media config: `./check-media-config.sh`
- [ ] **CRITICAL**: Increase upload limit in Admin Panel → Settings → Media Manager
- [ ] Test logo upload with monitoring: `./monitor-logs.sh upload`

---

## Why This Matters

The 1.5 MB default limit is very small by modern standards:
- A high-resolution PNG logo: 2-5 MB
- A simple SVG logo: 10-100 KB ✓ (would work)
- A JPEG photo-based logo: 500 KB - 3 MB
- A detailed vector logo exported as PNG: 1-10 MB

**Most professional logos exceed the default 1.5 MB limit**, which is why this is likely the primary cause of your upload failures.

---

## Summary

The issue is **NOT** just Docker/permissions (though those matter too). The main issue is that TastyIgniter's media manager has its own application-level upload size limit that defaults to a very conservative 1.5 MB.

**You must increase this limit in the admin panel settings** for logo uploads to work with larger files, even if PHP allows 64 MB uploads.

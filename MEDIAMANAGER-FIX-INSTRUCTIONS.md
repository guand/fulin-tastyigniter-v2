# Media Manager Input Fix - Deployment Instructions

## Problem
The TastyIgniter media manager's "Create Folder" dialog input field cannot be typed in because SweetAlert2's `showLoaderOnConfirm` setting creates a loading overlay that blocks input interaction.

## Solution Overview
This fix provides a custom JavaScript override that:
1. Intercepts SweetAlert2 dialogs and disables the blocking loader for input dialogs
2. Shows loading state on the button instead of blocking the entire dialog
3. Ensures the input field is always accessible with proper z-index and pointer events

## Installation Steps

### Step 1: Upload the Fix File

SSH into your server and upload the fix file:

```bash
# SSH into your server
ssh your-user@fulin-restaurant.com

# Navigate to the TastyIgniter public assets directory
cd /var/www/html/public/assets/js

# Create the directory if it doesn't exist
mkdir -p /var/www/html/public/assets/js

# Upload the mediamanager-fix.js file here
# You can use scp from your local machine:
# scp mediamanager-fix.js your-user@fulin-restaurant.com:/var/www/html/public/assets/js/
```

Or use SFTP to upload `mediamanager-fix.js` to `/var/www/html/public/assets/js/mediamanager-fix.js`

### Step 2: Add Script to Admin Layout

You have two options to include this script:

#### Option A: Via Admin Panel Extension (Recommended if available)

1. Log into your TastyIgniter admin panel
2. Go to **System > Extensions > Themes**
3. Edit your admin theme
4. Find the section to add custom scripts/assets
5. Add this line:
   ```html
   <script src="{{ asset('assets/js/mediamanager-fix.js') }}"></script>
   ```

#### Option B: Modify Admin Layout File Directly

1. SSH into your server
2. Locate the admin layout file (typically at):
   - `/var/www/html/app/admin/views/_layouts/default.blade.php`
   - OR `/var/www/html/themes/tastyigniter-orange/admin/views/_layouts/default.blade.php`
   - OR check in your active theme directory

3. Edit the layout file:
   ```bash
   nano /var/www/html/app/admin/views/_layouts/default.blade.php
   ```

4. Add this line before the closing `</body>` tag:
   ```html
   <script src="{{ asset('assets/js/mediamanager-fix.js') }}"></script>
   ```

5. Save the file (Ctrl+O, Enter, Ctrl+X in nano)

### Step 3: Clear Cache

Clear the TastyIgniter cache to ensure the changes take effect:

```bash
cd /var/www/html
php artisan cache:clear
php artisan view:clear
```

Or via admin panel:
1. Go to **System > Settings > Administrator settings**
2. Click **Clear Cache**

### Step 4: Test the Fix

1. Log into your admin panel
2. Navigate to **Media Manager**
3. Click the **New Folder** button
4. Try typing in the input field - it should now work!

## Alternative: Quick CSS-Only Fix

If the JavaScript fix doesn't work, you can try this simpler CSS-only approach:

Create a file at `/var/www/html/public/assets/css/mediamanager-fix.css`:

```css
/* Force input fields in SweetAlert2 to be interactive */
.swal2-input {
    pointer-events: auto !important;
    position: relative !important;
    z-index: 10000 !important;
}

/* Hide the loader that blocks input */
.swal2-popup .swal2-loader {
    display: none !important;
}

/* Ensure container doesn't block input */
.swal2-container {
    pointer-events: none !important;
}

.swal2-popup {
    pointer-events: auto !important;
}
```

Then add to your admin layout:
```html
<link rel="stylesheet" href="{{ asset('assets/css/mediamanager-fix.css') }}">
```

## Verification

After implementing the fix, you should see in browser console:
```
Media Manager input fix applied successfully.
```

And you should be able to:
- Click "New Folder" button
- Type in the input field without any issues
- Create folders successfully

## Troubleshooting

### Input still not working?

1. **Check browser console** for JavaScript errors
2. **Verify file upload**: Make sure the JS file is accessible at `https://www.fulin-restaurant.com/assets/js/mediamanager-fix.js`
3. **Clear browser cache**: Force refresh with Ctrl+Shift+R (or Cmd+Shift+R on Mac)
4. **Check file permissions**: Ensure the file is readable by the web server
   ```bash
   chmod 644 /var/www/html/public/assets/js/mediamanager-fix.js
   ```

### Script not loading?

1. View page source and verify the script tag is present
2. Check the network tab in browser dev tools to see if the script loads successfully
3. Verify the path matches your TastyIgniter installation structure

## Rollback

If you need to remove the fix:

1. Remove the script tag from your admin layout
2. Delete the file: `rm /var/www/html/public/assets/js/mediamanager-fix.js`
3. Clear cache again

## Need Help?

If this doesn't resolve the issue, we may need to:
1. Check the TastyIgniter version
2. Verify if there are any theme-specific overrides
3. Look for JavaScript errors in the browser console
4. Consider updating TastyIgniter core if this is a known bug

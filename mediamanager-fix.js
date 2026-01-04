/**
 * Media Manager Input Fix
 *
 * This script fixes the issue where the "Create Folder" input field
 * cannot be typed in due to SweetAlert2's showLoaderOnConfirm setting
 * blocking input interaction.
 *
 * Installation:
 * 1. Upload this file to: /public/assets/js/mediamanager-fix.js
 * 2. Add the script tag to your admin layout (see instructions below)
 */

(function() {
    'use strict';

    // Wait for DOM to be ready
    document.addEventListener('DOMContentLoaded', function() {

        // Override the media manager dialog behavior
        var originalShowDialog = window.Swal && window.Swal.fire;

        if (!originalShowDialog) {
            console.warn('SweetAlert2 not found. Media manager fix not applied.');
            return;
        }

        // Intercept all SweetAlert2 dialogs
        window.Swal.fire = function(options) {
            // If this is an input dialog (has input property), disable the loader during input
            if (options && options.input) {
                // Disable the loader that blocks input
                options.showLoaderOnConfirm = false;

                // If there's a preConfirm callback, wrap it to show loading state
                var originalPreConfirm = options.preConfirm;
                options.preConfirm = function(value) {
                    // Show loading state on the confirm button instead
                    window.Swal.showLoading();

                    // Call original preConfirm if it exists
                    if (originalPreConfirm) {
                        return originalPreConfirm(value);
                    }
                    return value;
                };
            }

            // Call the original Swal.fire with modified options
            return originalShowDialog.call(this, options);
        };

        // Copy over all other SweetAlert2 properties
        for (var prop in originalShowDialog) {
            if (originalShowDialog.hasOwnProperty(prop)) {
                window.Swal.fire[prop] = originalShowDialog[prop];
            }
        }

        console.log('Media Manager input fix applied successfully.');
    });

    // Additional fix: Remove any stray loader overlays that might block input
    document.addEventListener('click', function(e) {
        if (e.target.matches('[data-media-control="new-folder"], [data-media-control="rename-folder"]')) {
            // Small delay to let SweetAlert2 create the dialog
            setTimeout(function() {
                var input = document.querySelector('.swal2-input');
                if (input) {
                    // Ensure input is not blocked
                    input.style.pointerEvents = 'auto';
                    input.style.position = 'relative';
                    input.style.zIndex = '10000';
                    input.focus();

                    // Remove any blocking loader
                    var loader = document.querySelector('.swal2-loader');
                    if (loader) {
                        loader.style.display = 'none';
                    }
                }
            }, 100);
        }
    });

})();

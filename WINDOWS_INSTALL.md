# Windows MSIX Installation Guide

The Quick Sharing Windows app comes in two formats:
1. **MSIX Installer** - For proper installation with Start Menu integration
2. **Portable ZIP** - No installation needed, just extract and run

## Installing the MSIX (Recommended)

The MSIX package is self-signed, so you'll need to install the certificate first.

### Method 1: Automatic Installation (PowerShell)

1. Download the `.msix` file from the [Releases page](https://github.com/vishnu-iitp/quick_sharing/releases)
2. Open PowerShell **as Administrator**
3. Navigate to your Downloads folder:
   ```powershell
   cd $env:USERPROFILE\Downloads
   ```
4. Run this command (replace the filename if needed):
   ```powershell
   Add-AppxPackage -Path "quick_sharing.msix" -AllowUnsigned
   ```

### Method 2: Manual Certificate Installation

If Method 1 doesn't work, install the certificate manually:

1. **Right-click** on the `.msix` file
2. Select **Properties**
3. Go to the **Digital Signatures** tab
4. Select the signature and click **Details**
5. Click **View Certificate**
6. Click **Install Certificate...**
7. Select **Local Machine** (requires admin) or **Current User**
8. Choose **Place all certificates in the following store**
9. Click **Browse** and select **Trusted People**
10. Click **Next**, then **Finish**
11. Now **double-click** the `.msix` file to install

### Method 3: Enable Developer Mode (Easiest)

This is the simplest method:

1. Open **Windows Settings**
2. Go to **Privacy & Security** → **For developers** (or just search "Developer settings")
3. Turn on **Developer Mode**
4. Now you can **double-click** the `.msix` file to install directly

⚠️ **Note:** Developer Mode allows installation of any sideloaded app, so only use this if you trust the source.

## Using the Portable Version

If you don't want to deal with certificates:

1. Download `quick_sharing_windows_portable.zip`
2. Extract it to any folder
3. Run `quick_sharing.exe`

**Note:** The portable version won't appear in Start Menu and won't auto-update.

## After Installation

Once installed, you can:
- Find "Quick Sharing" in your Start Menu
- Pin it to Start or Taskbar
- Launch it like any other Windows app

## Troubleshooting

### "This app package's publisher certificate could not be verified"

This means the certificate isn't trusted. Use one of the installation methods above.

### "The app installation failed"

- Make sure you're on Windows 10 version 1809 or later
- Try enabling Developer Mode (Method 3)
- Or use the Portable version instead

### "Can't install because a higher version is already installed"

Uninstall the existing version first:
1. Open **Settings** → **Apps**
2. Find "Quick Sharing"
3. Click **Uninstall**
4. Then install the new version

## For Developers

To create a properly signed MSIX for distribution, you need:
1. A valid code signing certificate from a trusted CA (e.g., DigiCert, Sectigo)
2. Or publish through the Microsoft Store (automatic signing)

Self-signed certificates work fine for personal use or testing but require manual trust installation.

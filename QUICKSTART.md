# Quick Share - Quick Start Guide

Get started with Quick Share in 5 minutes!

## ⚡ Quick Setup

### 1. Prerequisites Check
```bash
flutter doctor
```
Ensure you have:
- ✅ Flutter SDK 3.9.2+
- ✅ Dart SDK 3.9.2+
- ✅ At least one platform configured (Android/Windows/Linux)

### 2. Install Dependencies
```bash
cd quick_sharing
flutter pub get
```

### 3. Run the App

**Android (Recommended for first run)**:
```bash
flutter run -d android
```

**Windows**:
```bash
flutter run -d windows
```

**Linux**:
```bash
flutter run -d linux
```

## 🎮 First Use Tutorial

### Step 1: Enable Receiving (Device A)
1. Open the app
2. Toggle the "Receiving" switch in the top-right to **ON**
3. You'll see "Now receiving files" notification
4. Your device is now discoverable!

### Step 2: Discover Devices (Device B)
1. Open the app on a second device
2. Both devices must be on the **same Wi-Fi network**
3. Wait a few seconds for Device A to appear in "Nearby Devices"
4. If it doesn't appear, tap the refresh button ↻

### Step 3: Send Files
1. On Device B, tap the **"Send Files"** button (bottom right)
2. OR tap directly on Device A's card in the list
3. Select one or more files from your device
4. Device A will receive a popup asking to Accept/Decline

### Step 4: Accept Transfer (Device A)
1. Review the incoming files
2. Tap **"Accept"** to receive the files
3. Watch the progress bar as files transfer
4. Files are saved automatically:
   - **Android**: Photos/Videos → Gallery, Others → Downloads
   - **Windows/Linux**: All files → Downloads folder

### Step 5: Verify Received Files
**Android**:
- Media: Open Gallery or Photos app
- Other files: Open Files app → Downloads folder

**Windows**:
- Open File Explorer → Downloads folder

**Linux**:
- Open Files → Downloads folder (or ~/Downloads)

## 🔧 Troubleshooting

### Problem: No devices appearing

**Solution**:
1. Verify both devices are on the same Wi-Fi network
2. Check that "Receiving" is enabled on the target device
3. Disable VPN on both devices
4. Wait 10-15 seconds, then tap refresh
5. Restart both apps if needed

### Problem: "Permission denied" on Android

**Solution**:
1. Go to Settings → Apps → Quick Share
2. Tap "Permissions"
3. Enable all storage and media permissions
4. For Android 11+, also enable "All files access"

### Problem: Transfer fails or gets stuck

**Solution**:
1. Check Wi-Fi connection is stable
2. Ensure receiving device has enough storage space
3. Try sending one file at a time
4. Restart both apps and try again

### Problem: Can't find received files (Android)

**Check**:
- **Images/Videos**: Gallery or Google Photos app
- **Other files**: Files app → Downloads
- Some devices: My Files → Internal storage → Download

## 📱 Platform-Specific Tips

### Android
- Grant all permissions when prompted
- For Android 11+, enable "All files access" in Settings
- Keep both apps open during transfer
- Media files auto-appear in Gallery

### Windows
- Allow through Windows Firewall when prompted
- Files save to: `C:\Users\YourName\Downloads`
- You can minimize the app during transfer

### Linux
- Files save to: `~/Downloads`
- If permissions issues, check Downloads folder is writable:
  ```bash
  ls -la ~/Downloads
  ```

## 🚀 Pro Tips

### Faster Discovery
- Keep "Receiving" enabled on devices you frequently receive files on
- Both devices will discover each other simultaneously

### Large Files
- For files >500MB, ensure stable Wi-Fi connection
- Consider using 5GHz Wi-Fi if available (faster)
- Close other network-intensive apps

### Multiple Files
- You can select multiple files at once
- Files are sent sequentially with individual progress bars
- All files appear together in the accept dialog

### Battery Optimization (Android)
To prevent interrupted transfers:
1. Settings → Battery → Battery optimization
2. Find "Quick Share"
3. Set to "Don't optimize"

## 🔒 Privacy & Security Notes

- ✅ Works only on local network (same Wi-Fi)
- ✅ Receiver must accept before files transfer
- ✅ No data sent to internet or cloud
- ⚠️ Files transfer without encryption (use trusted networks)
- ⚠️ Anyone on your network can discover your device

## 📊 Performance Expectations

| File Size | Expected Transfer Time (Wi-Fi 5) |
|-----------|----------------------------------|
| < 10 MB   | 1-5 seconds                      |
| 10-100 MB | 5-30 seconds                     |
| 100-500 MB| 30-150 seconds                   |
| 500 MB-1GB| 2-5 minutes                      |
| > 1 GB    | 5-10 minutes                     |

*Times vary based on Wi-Fi speed and network conditions*

## 🎯 Common Use Cases

### Scenario 1: Phone to PC (Quick Photo Transfer)
1. **PC**: Enable "Receiving"
2. **Phone**: Open app, tap PC name
3. **Phone**: Select photos from gallery
4. **PC**: Accept transfer
5. **Result**: Photos in PC's Downloads folder

### Scenario 2: PC to Phone (Document Sharing)
1. **Phone**: Enable "Receiving"
2. **PC**: Open app, select phone
3. **PC**: Choose PDFs or documents
4. **Phone**: Accept transfer
5. **Result**: Files in phone's Downloads

### Scenario 3: Linux to Windows
1. Both devices on same network
2. Windows enables "Receiving"
3. Linux sends files
4. Both can view progress in real-time

## 🆘 Getting More Help

If you encounter issues:

1. **Check the logs**: Run with verbose logging
   ```bash
   flutter run --verbose
   ```

2. **Review documentation**:
   - README.md: Overview and features
   - SETUP.md: Platform-specific setup
   - ARCHITECTURE.md: Technical details

3. **Common fixes**:
   ```bash
   # Clear cache and rebuild
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Report issues**: Include:
   - Platform (Android/Windows/Linux)
   - Error message or screenshot
   - Steps to reproduce
   - Output of `flutter doctor -v`

## 📚 Next Steps

Once you're comfortable:
- Read SETUP.md for platform-specific optimizations
- Check ARCHITECTURE.md to understand how it works
- Explore the code in lib/main.dart
- Build release versions for distribution

## 🎉 You're Ready!

You now know how to:
- ✅ Discover devices on your network
- ✅ Send files between devices
- ✅ Receive and save files
- ✅ Troubleshoot common issues

**Happy sharing! 📤📥**

---

*Need more help? Check the full documentation or open an issue on GitHub.*

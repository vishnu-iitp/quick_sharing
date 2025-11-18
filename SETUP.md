# Quick Share - Platform-Specific Setup Guide

This guide provides detailed setup instructions for each supported platform.

## 📱 Android Setup

### 1. Minimum Requirements
- Android SDK 21 (Android 5.0 Lollipop) or higher
- Android Studio with Flutter plugin installed

### 2. Permissions Configuration
The AndroidManifest.xml has been configured with all necessary permissions:
- Network access (INTERNET, WIFI_STATE, etc.)
- Storage access (for Android 10 and below)
- Media permissions (for Android 13+)

### 3. Build Configuration
No additional configuration needed. The app will automatically request permissions at runtime.

### 4. Testing on Physical Device
Recommended for best results:
```bash
flutter run -d <device-id>
```

### 5. Common Issues

**Issue**: "Storage permission denied"
- **Solution**: Go to Settings > Apps > Quick Share > Permissions and grant all storage permissions
- For Android 11+, enable "All files access" in Special app access

**Issue**: "Devices not discovered"
- **Solution**: Ensure Wi-Fi is enabled and both devices are on the same network
- Check that the app has network permissions

## 🪟 Windows Setup

### 1. Minimum Requirements
- Windows 10 (version 1809) or higher
- Visual Studio 2022 with "Desktop development with C++" workload

### 2. Visual Studio Configuration
Install the following components:
- MSVC v142 or later
- Windows 10 SDK (10.0.17763.0 or later)
- C++ CMake tools for Windows

### 3. Flutter Configuration
Ensure Flutter is configured for Windows development:
```bash
flutter config --enable-windows-desktop
flutter doctor
```

### 4. Firewall Configuration
The app creates an HTTP server on a dynamic port. You may need to:
1. Allow the app through Windows Firewall
2. When prompted, click "Allow access" for both private and public networks

### 5. Build and Run
```bash
flutter run -d windows
```

### 6. Release Build
```bash
flutter build windows --release
```
Executable will be in: `build/windows/runner/Release/`

### 7. Common Issues

**Issue**: "Build failed - Visual Studio not found"
- **Solution**: Install Visual Studio 2022 with C++ desktop development workload
- Run `flutter doctor` to verify installation

**Issue**: "Connection refused when transferring files"
- **Solution**: Check Windows Firewall settings
- Temporarily disable firewall to test, then add proper exception

## 🐧 Linux Setup

### 1. Minimum Requirements
- Ubuntu 20.04 or equivalent Linux distribution
- GCC 7.5 or newer

### 2. System Dependencies
Install required development libraries:

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  libgtk-3-dev \
  liblzma-dev \
  libstdc++-12-dev
```

**Fedora:**
```bash
sudo dnf install -y \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  gtk3-devel \
  xz-devel
```

**Arch Linux:**
```bash
sudo pacman -S \
  clang \
  cmake \
  ninja \
  pkgconf \
  gtk3
```

### 3. Flutter Configuration
Enable Linux desktop support:
```bash
flutter config --enable-linux-desktop
flutter doctor
```

### 4. Build and Run
```bash
flutter run -d linux
```

### 5. Release Build
```bash
flutter build linux --release
```
Binary will be in: `build/linux/x64/release/bundle/`

### 6. Network Configuration
The app should work without additional configuration, but if you have firewall issues:

**UFW (Ubuntu):**
```bash
# Allow the app's port range (if needed)
sudo ufw allow 8000:9999/tcp
```

**Firewalld (Fedora):**
```bash
sudo firewall-cmd --permanent --add-port=8000-9999/tcp
sudo firewall-cmd --reload
```

### 7. Common Issues

**Issue**: "GTK library not found"
- **Solution**: Install libgtk-3-dev package
- Run `flutter doctor` to verify

**Issue**: "Permission denied when saving files"
- **Solution**: Ensure the Downloads directory is writable
- Check: `ls -la ~/Downloads`

## 🔧 Development Tips

### Hot Reload
During development, use hot reload for faster iterations:
- Press `r` in the terminal
- Or use your IDE's hot reload button

### Debugging
Enable verbose logging:
```bash
flutter run --verbose
```

### Performance Profiling
Use Flutter DevTools:
```bash
flutter run --profile
# Then open DevTools from the provided URL
```

## 🧪 Testing Network Discovery

### Testing on the Same Machine
You can test the app by running two instances:

**Method 1: Virtual Devices**
- Run one instance on a physical device
- Run another on an emulator/simulator

**Method 2: Multiple Users (Linux)**
- Run instances as different users
- They'll discover each other on the same network

### Testing File Transfers
1. Enable "Receiving" on Device A
2. Device B should see Device A in the list
3. Select files on Device B and send to Device A
4. Accept the transfer on Device A
5. Check the Downloads folder (or Gallery for media)

## 📊 Performance Optimization

### Large File Transfers
The app uses streaming to handle large files efficiently. However, for very large files (>1GB):
- Ensure stable network connection
- Close other network-intensive apps
- Consider using a wired connection if possible

### Battery Optimization (Android)
To prevent Android from killing the app during transfers:
1. Go to Settings > Battery > Battery optimization
2. Find Quick Share and set to "Don't optimize"

## 🔒 Security Considerations

### Network Security
- The app only works on local networks (not over internet)
- No encryption is implemented (files transfer in plain HTTP)
- For sensitive files, ensure you're on a trusted network

### Future Enhancements (Not Implemented)
- End-to-end encryption
- Password-protected transfers
- Transfer history with audit logs

## 📝 Build Troubleshooting

### Clean Build
If you encounter persistent issues:
```bash
flutter clean
flutter pub get
flutter run
```

### Dependency Conflicts
Update dependencies to latest compatible versions:
```bash
flutter pub upgrade
```

### Platform-Specific Clean
```bash
# Android
cd android && ./gradlew clean && cd ..

# Windows
rm -rf build/windows

# Linux
rm -rf build/linux
```

## 🆘 Getting Help

If you encounter issues not covered here:
1. Check the console output for error messages
2. Run `flutter doctor -v` for system diagnostics
3. Enable verbose logging with `flutter run --verbose`
4. Check the GitHub issues page
5. Review Flutter's platform-specific setup documentation

## 📚 Additional Resources

- [Flutter Desktop Documentation](https://flutter.dev/desktop)
- [Flutter Android Setup](https://flutter.dev/docs/get-started/install)
- [Flutter Windows Setup](https://flutter.dev/docs/get-started/install/windows)
- [Flutter Linux Setup](https://flutter.dev/docs/get-started/install/linux)
- [Riverpod Documentation](https://riverpod.dev/)
- [Shelf Package Documentation](https://pub.dev/packages/shelf)

---

**Last Updated**: November 2025

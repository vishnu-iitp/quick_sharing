# Quick Share - Local Network File Sharing

A high-performance, cross-platform Flutter application for seamless file sharing over local networks, inspired by Google's Quick Share and Apple's AirDrop.

## 🚀 Features

### Core Functionality
- **Automatic Device Discovery**: Uses mDNS (Bonjour/Zeroconf) to discover devices on the same Wi-Fi network
- **Multi-File Transfer**: Send multiple files of any type simultaneously
- **Real-Time Progress**: Track transfer progress with percentage and visual feedback
- **Smart File Storage**: 
  - **Android**: Media files → Gallery, Other files → Downloads folder
  - **Windows/Linux**: All files → Downloads folder
- **Accept/Decline Requests**: Receiver controls incoming transfers with confirmation dialogs

### User Experience
- **Modern Dark Theme**: Tech-inspired, clean UI optimized for both mobile and desktop
- **Responsive Design**: Seamless experience on Android, Windows, and Linux
- **Real-Time Updates**: Live device list and transfer status updates
- **Error Handling**: Comprehensive error messages for all failure scenarios

## 🎯 Supported Platforms

- ✅ **Android** (API 21+)
- ✅ **Windows** (Windows 10+)
- ✅ **Linux** (Ubuntu 20.04+, Fedora, etc.)

## 📋 Prerequisites

- Flutter SDK 3.9.2 or higher
- Dart SDK 3.9.2 or higher
- For Android development: Android Studio with Android SDK
- For Windows development: Visual Studio 2022 with Desktop development with C++
- For Linux development: Required development libraries (see Flutter docs)

## 🛠️ Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd quick_sharing
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   
   For Android:
   ```bash
   flutter run -d android
   ```
   
   For Windows:
   ```bash
   flutter run -d windows
   ```
   
   For Linux:
   ```bash
   flutter run -d linux
   ```

## 🎮 How to Use

### Setting Up to Receive Files

1. Open the app on the receiving device
2. Toggle the "Receiving" switch in the top-right corner to ON
3. The device will now be discoverable by other devices on the network

### Sending Files

1. Ensure both sender and receiver are on the same Wi-Fi network
2. On the receiving device, enable "Receiving" mode
3. On the sending device:
   - Wait for the receiver to appear in the "Nearby Devices" list
   - Tap the "Send Files" button (or tap a device card)
   - Select files to send
   - Receiver will get a prompt to Accept/Decline
   - Once accepted, files transfer automatically

### Transfer Progress

- Active transfers appear in the "Active Transfers" section
- Progress bars show real-time transfer status
- Completed transfers display a success indicator
- Failed transfers show error messages

## 🏗️ Architecture

### State Management
- **Riverpod**: Modern, robust state management for reactive UI updates

### Services Layer
- **DiscoveryService**: Handles mDNS-based device discovery and advertisement
- **FileTransferService**: Manages HTTP server, file uploads, and downloads

### Network Stack
- **mDNS**: Device discovery using `multicast_dns` package
- **HTTP Server**: `shelf` package for receiving files
- **HTTP Client**: `dio` package for sending files with progress tracking

### Platform-Specific Logic
- **Permissions**: `permission_handler` for runtime permission requests
- **File Storage**: Platform checks for appropriate save locations
- **Device Info**: `device_info_plus` for device name retrieval

## 📦 Key Dependencies

```yaml
flutter_riverpod: ^2.5.1          # State management
multicast_dns: ^0.3.2+7           # mDNS service discovery
shelf: ^1.4.1                     # HTTP server
dio: ^5.7.0                       # HTTP client with progress
file_picker: ^8.1.6               # Cross-platform file picker
path_provider: ^2.1.5             # Platform directories
permission_handler: ^11.3.1        # Runtime permissions
image_gallery_saver: ^2.0.3       # Save to Android gallery
device_info_plus: ^11.1.1         # Device information
network_info_plus: ^6.0.2         # Network information
```

## 🔒 Permissions

### Android
- Internet access
- Network state access
- Wi-Fi state and multicast
- Storage (READ/WRITE_EXTERNAL_STORAGE for API < 33)
- Media permissions (READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, etc. for API 33+)
- Manage external storage (for saving files)

### Windows/Linux
- No special permissions required (uses standard user directories)

## 🐛 Troubleshooting

### Devices Not Appearing
- Ensure both devices are on the same Wi-Fi network
- Check that "Receiving" mode is enabled on the target device
- Disable any VPNs or firewalls that might block mDNS
- Try the refresh button to restart discovery

### Transfer Failures
- Verify network connection is stable
- Check storage permissions on Android
- Ensure sufficient storage space on receiving device
- Check firewall settings aren't blocking the HTTP server

### Permission Issues (Android)
- Grant all requested permissions in Settings > Apps > Quick Share
- On Android 11+, enable "All files access" if available

## 🔧 Configuration

### Network Settings
- Default service type: `_quickshare._tcp`
- Default port: 9876 (for service advertisement)
- HTTP server: Dynamic port allocation for file transfers

### Customization
You can modify these constants in `main.dart`:
```dart
static const String serviceType = '_quickshare._tcp';
static const int servicePort = 9876;
```

## 🚀 Building for Production

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### Windows
```bash
flutter build windows --release
```

### Linux
```bash
flutter build linux --release
```

## 📝 Code Structure

```
lib/
└── main.dart
    ├── Models (DiscoveredDevice, FileTransfer, TransferRequest)
    ├── Services (DiscoveryService, FileTransferService)
    ├── State Management (Riverpod providers)
    └── UI Components (HomePage, Device cards, Transfer cards)
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Inspired by Google Quick Share and Apple AirDrop
- Built with Flutter and Dart
- Uses modern Flutter best practices and architecture patterns

## 📞 Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

**Note**: This application requires devices to be on the same local network. It does not work over the internet or across different networks.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

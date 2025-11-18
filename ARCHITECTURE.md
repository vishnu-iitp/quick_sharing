# Quick Share - Technical Architecture

This document provides a comprehensive overview of the application's architecture, design decisions, and implementation details.

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer (Flutter)                    │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  HomePage   │  │ Device Cards │  │ Transfer Cards│  │
│  └─────────────┘  └──────────────┘  └───────────────┘  │
└────────────────────────┬────────────────────────────────┘
                         │ Riverpod Providers
┌────────────────────────┴────────────────────────────────┐
│               State Management Layer                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Providers & Notifiers (Riverpod)               │   │
│  │  - discoveryServiceProvider                     │   │
│  │  - fileTransferServiceProvider                  │   │
│  │  - discoveredDevicesProvider                    │   │
│  │  - transferProgressProvider                     │   │
│  └─────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────┐
│                  Service Layer                           │
│  ┌───────────────────┐      ┌──────────────────────┐   │
│  │ DiscoveryService  │      │ FileTransferService  │   │
│  │ - mDNS Discovery  │      │ - HTTP Server        │   │
│  │ - Device Registry │      │ - File Upload/Send   │   │
│  └───────────────────┘      └──────────────────────┘   │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────┐
│              Platform Integration Layer                  │
│  ┌─────────────┐ ┌──────────────┐ ┌─────────────────┐  │
│  │ File System │ │ Permissions  │ │ Network Info    │  │
│  │ (Platform)  │ │ (Android)    │ │ (WiFi IP)       │  │
│  └─────────────┘ └──────────────┘ └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 📦 Core Components

### 1. Models (Data Layer)

#### DiscoveredDevice
Represents a device discovered on the network.

```dart
class DiscoveredDevice {
  final String id;           // Unique device identifier
  final String name;         // Human-readable device name
  final String ipAddress;    // IPv4 address
  final DateTime discoveredAt; // Timestamp of discovery
}
```

**Purpose**: Maintain information about available devices for file transfer.

#### FileTransfer
Tracks the state of a file transfer operation.

```dart
class FileTransfer {
  final String id;
  final String fileName;
  final int fileSize;
  final String senderName;
  final String receiverName;
  final TransferStatus status;
  final double progress;     // 0.0 to 1.0
  final String? errorMessage;
}
```

**States**: 
- `pending`: Request sent, awaiting acceptance
- `accepted`: Receiver accepted, preparing transfer
- `transferring`: Active file transfer in progress
- `completed`: Successfully transferred
- `failed`: Transfer failed with error
- `declined`: Receiver declined the transfer

#### TransferRequest
Represents an incoming file transfer request.

```dart
class TransferRequest {
  final String id;
  final String senderName;
  final String senderIp;
  final List<FileMetadata> files;
  final int port;
}
```

**Purpose**: Encapsulate all information needed for the receiver to make an informed decision.

### 2. Services Layer

#### DiscoveryService
Handles network device discovery using mDNS (Multicast DNS).

**Key Responsibilities**:
- Advertise this device on the network
- Discover other devices running the app
- Maintain a registry of active devices
- Handle device timeout and removal

**Implementation Details**:
```dart
- Service Type: _quickshare._tcp
- Port: 9876 (for service advertisement)
- Advertisement Interval: Every 5 seconds
- Uses multicast_dns package
```

**mDNS Flow**:
1. Start mDNS client
2. Advertise service with PTR, SRV, and TXT records
3. Listen for other devices' advertisements
4. Query for A records to get IP addresses
5. Maintain device list with timestamps

#### FileTransferService
Manages file sending and receiving operations.

**Receiving Files**:
- Starts an HTTP server on a dynamic port
- Listens for incoming transfer requests
- Handles multipart/form-data uploads
- Saves files to platform-appropriate locations

**Sending Files**:
- Sends transfer request to receiver
- Waits for acceptance
- Uploads files using HTTP POST with multipart
- Tracks and reports progress

**HTTP Server Implementation**:
```dart
- Framework: Shelf
- Endpoints:
  - POST /request: Receive transfer request
  - POST /upload: Receive file data
- Dynamic port allocation
- Streaming support for large files
```

### 3. State Management (Riverpod)

#### Provider Architecture

**Service Providers** (Singleton):
```dart
final discoveryServiceProvider = Provider<DiscoveryService>
final fileTransferServiceProvider = Provider<FileTransferService>
```

**Stream Providers** (Real-time updates):
```dart
final discoveredDevicesProvider = StreamProvider<DiscoveredDevice>
final transferRequestProvider = StreamProvider<TransferRequest>
final transferProgressProvider = StreamProvider<FileTransfer>
```

**State Providers** (Simple state):
```dart
final isReceivingProvider = StateProvider<bool>
final deviceNameProvider = FutureProvider<String>
```

**Benefits of Riverpod**:
- Compile-time safety
- No BuildContext needed for providers
- Automatic disposal of resources
- Easy testing and mocking

### 4. Platform-Specific Logic

#### File Storage Strategy

**Android**:
```dart
Media Files (.jpg, .png, .mp4, etc.)
  → Gallery (via ImageGallerySaver)
  → Accessible in Photos app

Other Files (.pdf, .zip, .txt, etc.)
  → /storage/emulated/0/Download
  → Accessible in Files app
```

**Windows/Linux**:
```dart
All Files
  → ~/Downloads directory
  → Retrieved via path_provider
```

#### Permission Handling

**Android Permission Flow**:
1. Check if permission is granted
2. If not, request permission
3. If denied, request MANAGE_EXTERNAL_STORAGE
4. Handle denial gracefully with user feedback

**Required Permissions**:
- Storage (API < 33): READ/WRITE_EXTERNAL_STORAGE
- Media (API ≥ 33): READ_MEDIA_IMAGES, READ_MEDIA_VIDEO
- Network: INTERNET, WIFI_STATE, MULTICAST

## 🔄 Key Workflows

### Device Discovery Flow

```
┌──────────┐
│   Start  │
└────┬─────┘
     │
     ▼
┌─────────────────────┐
│ Initialize mDNS     │
│ Client              │
└─────┬───────────────┘
      │
      ├──────────────────┐
      │                  │
      ▼                  ▼
┌─────────────┐   ┌─────────────┐
│ Start       │   │ Start       │
│ Advertising │   │ Discovery   │
│ (if recv.)  │   │ (browse)    │
└─────┬───────┘   └──────┬──────┘
      │                  │
      │                  ▼
      │           ┌─────────────┐
      │           │ Receive PTR │
      │           │ Records     │
      │           └──────┬──────┘
      │                  │
      │                  ▼
      │           ┌─────────────┐
      │           │ Query SRV   │
      │           │ Records     │
      │           └──────┬──────┘
      │                  │
      │                  ▼
      │           ┌─────────────┐
      │           │ Query A     │
      │           │ Records     │
      │           └──────┬──────┘
      │                  │
      └──────────────────┼──────┐
                         │      │
                         ▼      ▼
                  ┌─────────────────┐
                  │ Update Device   │
                  │ List in UI      │
                  └─────────────────┘
```

### File Transfer Flow (Sender → Receiver)

```
    Sender                         Receiver
      │                               │
      ├─ 1. Select Files              │
      │                               │
      ├─ 2. Select Target Device      │
      │                               │
      ├─ 3. Send Transfer Request ───>│
      │                               │
      │                          ├─ 4. Show Dialog
      │                          │    (Accept/Decline)
      │                               │
      │<─── 5. Accept Response ───────┤
      │                               │
      │                          ├─ 6. Start HTTP Server
      │                          │
      ├─ 7. Upload Files ──────────>  │
      │    (multipart POST)           │
      │                               │
      ├─ 8. Track Progress            │
      │                               │
      │                          ├─ 9. Receive & Save
      │                          │    - Android: Gallery/Downloads
      │                          │    - Desktop: Downloads
      │                               │
      │<─── 10. Completion Response ──┤
      │                               │
      ├─ 11. Show Success         ├─ 11. Show Success
      │                               │
```

### File Reception and Storage Flow

```
┌──────────────────┐
│ Receive File     │
│ Data (bytes)     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Detect Platform  │
└────┬────────┬────┘
     │        │
Android   Windows/Linux
     │        │
     ▼        ▼
┌─────────────────┐   ┌──────────────┐
│ Check File Type │   │ Get Downloads│
│ (extension)     │   │ Directory    │
└──┬──────────┬───┘   └──────┬───────┘
   │          │              │
Media     Other             │
   │          │              │
   ▼          ▼              ▼
┌────────┐ ┌─────────┐  ┌─────────┐
│Gallery │ │Download │  │Download │
│Saver   │ │Folder   │  │Folder   │
└────────┘ └─────────┘  └─────────┘
```

## 🎨 UI Component Architecture

### HomePage Structure

```
HomePage (ConsumerStatefulWidget)
│
├─ AppBar
│  ├─ Title (Device Name)
│  └─ Receiving Toggle
│
├─ Active Transfers Section
│  └─ Transfer Cards (List)
│     ├─ File Name
│     ├─ Progress Bar
│     └─ Status Icon
│
├─ Nearby Devices Section
│  ├─ Refresh Button
│  └─ Device Cards (List)
│     ├─ Device Icon
│     ├─ Device Name
│     └─ IP Address
│
└─ FAB (Send Files)
```

### Responsive Design

**Mobile (< 600px)**:
- Single column layout
- Full-width cards
- Bottom sheet for device selection
- Compact spacing

**Desktop (≥ 600px)**:
- Grid layout for devices
- Wider cards with more spacing
- Dialog for device selection
- Enhanced visual hierarchy

## 🔐 Security Considerations

### Current Implementation
- **No encryption**: Files transfer over plain HTTP
- **Local network only**: mDNS only works on LAN
- **No authentication**: Any device can discover and connect
- **Permission-based security**: Receiver must accept transfers

### Recommendations for Production
1. Implement TLS/SSL for file transfers
2. Add device pairing with authentication tokens
3. Implement transfer history and audit logs
4. Add options for password-protected transfers
5. Implement file integrity verification (checksums)

## ⚡ Performance Optimizations

### Memory Efficiency
- **Streaming**: Files are streamed, not loaded entirely into memory
- **Chunk processing**: Multipart data processed in chunks
- **Lazy loading**: Device list updated incrementally

### Network Efficiency
- **Progress reporting**: Callbacks prevent UI blocking
- **Connection pooling**: Reuse HTTP connections
- **Timeout handling**: Prevent hung connections

### UI Responsiveness
- **Async operations**: All network operations are asynchronous
- **Stream-based updates**: UI updates only when state changes
- **Debouncing**: Discovery requests throttled

## 🧪 Testing Strategy

### Unit Tests (Recommended)
```dart
test/
├── models/
│   ├── discovered_device_test.dart
│   ├── file_transfer_test.dart
│   └── transfer_request_test.dart
│
├── services/
│   ├── discovery_service_test.dart
│   └── file_transfer_service_test.dart
│
└── providers/
    └── providers_test.dart
```

### Integration Tests
```dart
integration_test/
├── device_discovery_test.dart
├── file_transfer_test.dart
└── permission_handling_test.dart
```

## 📊 Error Handling Strategy

### Error Categories

1. **Network Errors**
   - WiFi disconnected
   - Target device unreachable
   - Timeout during transfer
   - **Handling**: Retry logic, user notification

2. **Permission Errors**
   - Storage permission denied
   - Network permission denied
   - **Handling**: Request permissions, show instructions

3. **File System Errors**
   - Insufficient storage
   - File access denied
   - **Handling**: Check space, fallback locations

4. **Transfer Errors**
   - Receiver declined
   - Connection interrupted
   - Corrupted data
   - **Handling**: Clean up, notify user, log error

### Error Recovery
```dart
try {
  await performOperation();
} on SocketException {
  // Network error
  showNetworkError();
  retryWithExponentialBackoff();
} on PermissionException {
  // Permission denied
  requestPermissions();
} catch (e) {
  // Generic error
  logError(e);
  showUserFriendlyMessage();
}
```

## 🔄 Future Enhancements

### Short-term
- [ ] QR code pairing for device discovery
- [ ] Transfer history and logs
- [ ] Pause/resume functionality
- [ ] Multiple simultaneous transfers

### Medium-term
- [ ] End-to-end encryption
- [ ] Cloud backup integration
- [ ] Compression options
- [ ] iOS support

### Long-term
- [ ] Peer-to-peer over internet (with relay server)
- [ ] Group sharing (multiple recipients)
- [ ] File synchronization
- [ ] Chat functionality

## 📚 Dependencies Analysis

### Core Dependencies
- **flutter_riverpod**: State management - chosen for type safety and performance
- **multicast_dns**: mDNS implementation - official Dart package
- **shelf**: HTTP server - lightweight and well-maintained
- **dio**: HTTP client - progress tracking and interceptors
- **file_picker**: File selection - cross-platform support

### Platform Dependencies
- **permission_handler**: Android permissions - most comprehensive solution
- **path_provider**: Directory access - official Flutter package
- **image_gallery_saver**: Gallery access - Android-specific need
- **device_info_plus**: Device details - cross-platform support

## 🎓 Learning Resources

For developers working on this codebase:
- [Riverpod Documentation](https://riverpod.dev/)
- [mDNS RFC 6762](https://datatracker.ietf.org/doc/html/rfc6762)
- [HTTP Multipart Forms](https://www.w3.org/Protocols/rfc1341/7_2_Multipart.html)
- [Flutter Platform Channels](https://flutter.dev/docs/development/platform-integration/platform-channels)

---

**Document Version**: 1.0  
**Last Updated**: November 2025  
**Maintained by**: Development Team

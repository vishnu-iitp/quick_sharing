import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================

void main() {
  runApp(const ProviderScope(child: QuickShareApp()));
}

// ============================================================================
// APP ROOT
// ============================================================================

class QuickShareApp extends StatelessWidget {
  const QuickShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Share',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00D9FF),
          secondary: const Color(0xFF6C63FF),
          surface: const Color(0xFF1A1F3A),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1F3A),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D9FF),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ============================================================================
// MODELS
// ============================================================================

/// Represents a discovered device on the network
class DiscoveredDevice {
  final String id;
  final String name;
  final String ipAddress;
  final int serverPort;
  final DateTime discoveredAt;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.serverPort,
    required this.discoveredAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents a file transfer
class FileTransfer {
  final String id;
  final String fileName;
  final int fileSize;
  final String senderName;
  final String receiverName;
  final TransferStatus status;
  final double progress;
  final String? errorMessage;
  final double? speedBytesPerSecond; // Transfer speed in bytes/second
  final DateTime? startTime; // When transfer started

  FileTransfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.senderName,
    required this.receiverName,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    this.speedBytesPerSecond,
    this.startTime,
  });

  FileTransfer copyWith({
    TransferStatus? status,
    double? progress,
    String? errorMessage,
    double? speedBytesPerSecond,
    DateTime? startTime,
  }) {
    return FileTransfer(
      id: id,
      fileName: fileName,
      fileSize: fileSize,
      senderName: senderName,
      receiverName: receiverName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      startTime: startTime ?? this.startTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum TransferStatus {
  pending,
  accepted,
  transferring,
  completed,
  failed,
  declined,
}

/// Represents an incoming transfer request
class TransferRequest {
  final String id;
  final String senderName;
  final String senderIp;
  final List<FileMetadata> files;
  final int port;

  TransferRequest({
    required this.id,
    required this.senderName,
    required this.senderIp,
    required this.files,
    required this.port,
  });

  factory TransferRequest.fromJson(Map<String, dynamic> json) {
    return TransferRequest(
      id: json['id'],
      senderName: json['senderName'],
      senderIp: json['senderIp'],
      port: json['port'],
      files: (json['files'] as List)
          .map((f) => FileMetadata.fromJson(f))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderName': senderName,
      'senderIp': senderIp,
      'port': port,
      'files': files.map((f) => f.toJson()).toList(),
    };
  }
}

class FileMetadata {
  final String name;
  final int size;
  final String? mimeType;

  FileMetadata({required this.name, required this.size, this.mimeType});

  factory FileMetadata.fromJson(Map<String, dynamic> json) {
    return FileMetadata(
      name: json['name'],
      size: json['size'],
      mimeType: json['mimeType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'size': size, 'mimeType': mimeType};
  }
}

// ============================================================================
// SERVICES
// ============================================================================

/// Service for UDP broadcast-based device discovery
class DiscoveryService {
  static const int discoveryPort = 9876;
  static const String broadcastMessage = 'QUICKSHARE_DISCOVER';
  static const String responsePrefix = 'QUICKSHARE_DEVICE:';

  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  final StreamController<DiscoveredDevice> _deviceController =
      StreamController<DiscoveredDevice>.broadcast();
  final Map<String, DiscoveredDevice> _discoveredDevices = {};
  String? _deviceName;
  String? _deviceId;
  String? _localIp;
  int? _serverPort;

  Stream<DiscoveredDevice> get deviceStream => _deviceController.stream;
  List<DiscoveredDevice> get devices => _discoveredDevices.values.toList();

  Future<void> initialize() async {
    _deviceName = await _getDeviceName();
    _deviceId = const Uuid().v4();
    _localIp = await _getLocalIp();
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return linuxInfo.prettyName;
      }
    } catch (e) {
      debugPrint('Error getting device name: $e');
    }
    return 'Unknown Device';
  }

  Future<String> _getLocalIp() async {
    try {
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      return wifiIP ?? '127.0.0.1';
    } catch (e) {
      debugPrint('Error getting local IP: $e');
      return '127.0.0.1';
    }
  }

  /// Start listening for discovery broadcasts
  Future<void> startListening(int serverPort) async {
    try {
      _serverPort = serverPort;

      // Bind to discovery port to listen for broadcasts
      _listenSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      );

      _listenSocket!.broadcastEnabled = true;

      debugPrint('Listening for discovery on port $discoveryPort');

      _listenSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenSocket!.receive();
          if (datagram == null) return;

          final message = utf8.decode(datagram.data);
          final senderIp = datagram.address.address;

          // Ignore messages from self
          if (senderIp == _localIp) return;

          if (message == broadcastMessage) {
            // Received discovery request, send response
            _sendResponse(datagram.address);
          } else if (message.startsWith(responsePrefix)) {
            // Received device announcement
            _handleDeviceResponse(message, senderIp);
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting listener: $e');
    }
  }

  void _sendResponse(InternetAddress requester) {
    try {
      if (_deviceName == null || _deviceId == null || _serverPort == null)
        return;

      final response = '$responsePrefix$_deviceId|$_deviceName|$_serverPort';
      final data = utf8.encode(response);

      _listenSocket?.send(data, requester, discoveryPort);
      debugPrint('Sent response to $requester');
    } catch (e) {
      debugPrint('Error sending response: $e');
    }
  }

  void _handleDeviceResponse(String message, String ipAddress) {
    try {
      // Parse message: QUICKSHARE_DEVICE:deviceId|deviceName|serverPort
      final parts = message.substring(responsePrefix.length).split('|');
      if (parts.length != 3) return;

      final deviceId = parts[0];
      final deviceName = parts[1];
      final serverPort = int.tryParse(parts[2]);

      if (deviceId == _deviceId) return; // Ignore self
      if (serverPort == null) return;

      final device = DiscoveredDevice(
        id: deviceId,
        name: deviceName,
        ipAddress: ipAddress,
        serverPort: serverPort,
        discoveredAt: DateTime.now(),
      );

      if (!_discoveredDevices.containsKey(device.id)) {
        _discoveredDevices[device.id] = device;
        _deviceController.add(device);
        debugPrint(
          'Discovered device: ${device.name} at ${device.ipAddress}:$serverPort',
        );
      } else {
        // Update timestamp for existing device
        _discoveredDevices[device.id] = device;
      }
    } catch (e) {
      debugPrint('Error handling device response: $e');
    }
  }

  /// Start broadcasting discovery messages
  Future<void> startDiscovery() async {
    try {
      // Create broadcast socket
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // Use any available port for sending
      );

      _broadcastSocket!.broadcastEnabled = true;

      debugPrint('Started discovery broadcasts');

      // Send initial broadcast immediately
      _sendDiscoveryBroadcast();

      // Broadcast every 3 seconds
      _broadcastTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _sendDiscoveryBroadcast();
      });

      // Clean up stale devices every 15 seconds
      _cleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _cleanupStaleDevices();
      });
    } catch (e) {
      debugPrint('Error starting discovery: $e');
    }
  }

  void _sendDiscoveryBroadcast() {
    try {
      final data = utf8.encode(broadcastMessage);

      // Send to broadcast address
      _broadcastSocket?.send(
        data,
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );

      // Also send device announcement
      if (_deviceName != null && _deviceId != null && _serverPort != null) {
        final announcement =
            '$responsePrefix$_deviceId|$_deviceName|$_serverPort';
        final announcementData = utf8.encode(announcement);

        _broadcastSocket?.send(
          announcementData,
          InternetAddress('255.255.255.255'),
          discoveryPort,
        );
      }
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
    }
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    final staleDevices = <String>[];

    for (final entry in _discoveredDevices.entries) {
      final age = now.difference(entry.value.discoveredAt).inSeconds;
      if (age > 30) {
        // Device hasn't responded in 30 seconds
        staleDevices.add(entry.key);
      }
    }

    for (final id in staleDevices) {
      _discoveredDevices.remove(id);
      debugPrint('Removed stale device: $id');
    }
  }

  /// Start advertising this device on the network
  Future<void> startAdvertising() async {
    // UDP broadcast handles both discovery and advertising
    // No separate advertising needed
    debugPrint('Advertising via UDP broadcasts');
  }

  /// Stop all discovery and advertising
  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _broadcastSocket?.close();
    _listenSocket?.close();
    _discoveredDevices.clear();
  }

  void dispose() {
    stop();
    _deviceController.close();
  }
}

/// Service for handling file transfers
class FileTransferService {
  HttpServer? _httpServer;
  int? _serverPort;
  final StreamController<TransferRequest> _transferRequestController =
      StreamController<TransferRequest>.broadcast();
  final StreamController<FileTransfer> _transferProgressController =
      StreamController<FileTransfer>.broadcast();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  Stream<TransferRequest> get transferRequestStream =>
      _transferRequestController.stream;
  Stream<FileTransfer> get transferProgressStream =>
      _transferProgressController.stream;

  int? get serverPort => _serverPort;

  /// Initialize notifications
  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);

      await _notificationsPlugin.initialize(initSettings);

      // Request notification permission for Android 13+
      if (Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }

      _notificationsInitialized = true;
      debugPrint('Notifications initialized');
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Show notification for received file
  Future<void> _showReceivedFileNotification(
    String filename,
    String location,
  ) async {
    try {
      await _initializeNotifications();

      const androidDetails = AndroidNotificationDetails(
        'file_transfers',
        'File Transfers',
        channelDescription: 'Notifications for received files',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        filename.hashCode, // Use filename hash as notification ID
        'File Received',
        '$filename saved to $location',
        notificationDetails,
      );

      debugPrint('Notification shown for: $filename');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Start HTTP server to receive files
  Future<int?> startReceivingServer(String deviceName) async {
    try {
      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler(_handleRequest);

      _httpServer = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        0, // Use any available port
      );

      _serverPort = _httpServer!.port;
      debugPrint('Server started on port $_serverPort');
      return _serverPort;
    } catch (e) {
      debugPrint('Error starting server: $e');
      return null;
    }
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    if (request.method == 'POST' && request.url.path == 'upload') {
      return await _handleFileUpload(request);
    } else if (request.method == 'POST' && request.url.path == 'request') {
      return await _handleTransferRequest(request);
    }
    return shelf.Response.notFound('Not Found');
  }

  Future<shelf.Response> _handleTransferRequest(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body);
      final transferRequest = TransferRequest.fromJson(data);

      _transferRequestController.add(transferRequest);

      return shelf.Response.ok(json.encode({'status': 'pending'}));
    } catch (e) {
      debugPrint('Error handling transfer request: $e');
      return shelf.Response.internalServerError(
        body: json.encode({'error': e.toString()}),
      );
    }
  }

  Future<shelf.Response> _handleFileUpload(shelf.Request request) async {
    try {
      debugPrint('Received upload request');

      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        debugPrint('Invalid content type: $contentType');
        return shelf.Response.badRequest(
          body: json.encode({
            'error': 'Content-Type must be multipart/form-data',
          }),
        );
      }

      // Extract boundary from content-type
      final boundaryMatch = RegExp(r'boundary=(.+)$').firstMatch(contentType);
      if (boundaryMatch == null) {
        debugPrint('No boundary found in content-type');
        return shelf.Response.badRequest(
          body: json.encode({'error': 'No boundary in multipart data'}),
        );
      }

      final boundary = boundaryMatch.group(1)!;
      debugPrint('Boundary: $boundary');

      // Stream file directly to disk instead of loading into memory
      final result = await _streamMultipartToDisk(request.read(), boundary);
      if (result == null) {
        debugPrint('Failed to stream multipart data');
        return shelf.Response.badRequest(
          body: json.encode({'error': 'Failed to process multipart data'}),
        );
      }

      final filename = result['filename'] as String;
      final tempFilePath = result['tempPath'] as String;

      debugPrint('Streamed file: $filename to temp location');

      // Move the file to final location
      final savedLocation = await _moveToFinalLocation(filename, tempFilePath);

      debugPrint('File saved successfully to: $savedLocation');

      // Show notification
      await _showReceivedFileNotification(filename, savedLocation);

      // Send success response immediately
      debugPrint('Sending success response for: $filename');
      return shelf.Response.ok(
        json.encode({
          'status': 'success',
          'filename': filename,
          'location': savedLocation,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Connection': 'close', // Ensure connection is properly closed
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Error handling upload: $e');
      debugPrint('Stack trace: $stackTrace');
      return shelf.Response.internalServerError(
        body: json.encode({'error': e.toString()}),
      );
    }
  }

  /// Stream multipart data directly to disk without loading into memory
  Future<Map<String, dynamic>?> _streamMultipartToDisk(
    Stream<List<int>> stream,
    String boundary,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFilePath =
          '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.tmp';
      final tempFile = File(tempFilePath);
      final sink = tempFile.openWrite();

      String? filename;
      bool inHeader = true;
      final boundaryBytes = utf8.encode('--$boundary');
      final headerEndBytes = [13, 10, 13, 10]; // \r\n\r\n
      List<int> buffer = [];

      await for (final chunk in stream) {
        buffer.addAll(chunk);

        if (inHeader) {
          // Look for header end
          final headerEndIndex = _findBytes(buffer, headerEndBytes, 0);
          if (headerEndIndex != -1) {
            // Extract headers
            final headerBytes = buffer.sublist(0, headerEndIndex);
            final headerText = utf8.decode(headerBytes);

            // Extract filename
            final filenameMatch = RegExp(
              r'filename="([^"]+)"',
            ).firstMatch(headerText);
            filename = filenameMatch?.group(1) ?? 'unnamed_file';

            // Remove header from buffer and switch to body mode
            buffer = buffer.sublist(headerEndIndex + 4);
            inHeader = false;
          }
        }

        // If we have a filename and we're processing the body
        if (!inHeader && filename != null) {
          // Write buffer to file, but keep last few bytes in case boundary spans chunks
          if (buffer.length > boundaryBytes.length + 10) {
            final writeLength = buffer.length - (boundaryBytes.length + 10);
            sink.add(buffer.sublist(0, writeLength));
            buffer = buffer.sublist(writeLength);
          }
        }
      }

      // Write remaining bytes, but remove trailing boundary
      if (buffer.isNotEmpty) {
        // Find the final boundary
        final finalBoundaryIndex = _findBytes(buffer, boundaryBytes, 0);
        if (finalBoundaryIndex != -1) {
          // Write everything before the boundary (excluding \r\n before it)
          final contentEnd = finalBoundaryIndex - 2;
          if (contentEnd > 0) {
            sink.add(buffer.sublist(0, contentEnd));
          }
        } else {
          sink.add(buffer);
        }
      }

      await sink.flush();
      await sink.close();

      if (filename == null) {
        await tempFile.delete();
        return null;
      }

      return {'filename': filename, 'tempPath': tempFilePath};
    } catch (e) {
      debugPrint('Error streaming multipart: $e');
      return null;
    }
  }

  /// Move file from temp location to final destination
  Future<String> _moveToFinalLocation(
    String filename,
    String tempFilePath,
  ) async {
    try {
      final tempFile = File(tempFilePath);
      String location;

      if (Platform.isAndroid) {
        location = await _moveFileAndroid(filename, tempFile);
      } else if (Platform.isWindows || Platform.isLinux) {
        location = await _moveFileDesktop(filename, tempFile);
      } else {
        location = 'Unknown';
      }

      // Clean up temp file if it still exists
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return location;
    } catch (e) {
      debugPrint('Error moving file: $e');
      rethrow;
    }
  }

  Future<String> _moveFileAndroid(String filename, File tempFile) async {
    // Request permissions
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      final manageStatus = await Permission.manageExternalStorage.request();
      if (!manageStatus.isGranted) {
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted) {
          throw Exception('Storage permission denied');
        }
      }
    }

    final extension = path.extension(filename).toLowerCase();
    final isImage = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
    ].contains(extension);
    final isVideo = ['.mp4', '.mov', '.avi', '.mkv'].contains(extension);

    if (isImage || isVideo) {
      try {
        // Save to gallery using gal package
        if (isVideo) {
          await Gal.putVideo(tempFile.path);
        } else {
          await Gal.putImage(tempFile.path);
        }
        return 'Gallery';
      } catch (e) {
        debugPrint('Error saving to gallery: $e');
        // Fallback to Downloads
        return await _moveToDownloads(filename, tempFile);
      }
    } else {
      // Save to Downloads
      return await _moveToDownloads(filename, tempFile);
    }
  }

  Future<String> _moveToDownloads(String filename, File tempFile) async {
    final directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final destFile = File('${directory.path}/$filename');
    await tempFile.copy(destFile.path);
    return 'Downloads';
  }

  Future<String> _moveFileDesktop(String filename, File tempFile) async {
    final directory = await getDownloadsDirectory();
    if (directory == null) {
      throw Exception('Could not access Downloads directory');
    }

    final destFile = File('${directory.path}/$filename');
    await tempFile.copy(destFile.path);
    return 'Downloads';
  }

  /// Helper to find a byte pattern in a list
  int _findBytes(List<int> data, List<int> pattern, int startIndex) {
    for (int i = startIndex; i <= data.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  /// Send files to a receiver
  Future<void> sendFiles({
    required String receiverIp,
    required int receiverPort,
    required List<PlatformFile> files,
    required String senderName,
    required String receiverName,
    required Function(String fileId, double progress) onProgress,
  }) async {
    final List<Future> transferFutures =
        []; // List to hold all transfer futures

    for (final file in files) {
      final transferId = const Uuid().v4();
      final startTime = DateTime.now();

      final fileTransfer = FileTransfer(
        id: transferId,
        fileName: file.name,
        fileSize: file.size,
        senderName: senderName,
        receiverName: receiverName,
        status: TransferStatus.transferring,
        startTime: startTime,
      );

      _transferProgressController.add(fileTransfer);

      // Create the future but DON'T await it yet - this starts the transfer immediately
      final transferFuture = () async {
        // Create a new Dio instance for each file to avoid connection pooling issues
        final dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(minutes: 10),
            receiveTimeout: const Duration(minutes: 10),
          ),
        );

        int lastSent = 0;
        DateTime lastTime = startTime;
        bool completed = false;

        try {
          // Use file path for streaming instead of loading bytes into memory
          final formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              file.path!,
              filename: file.name,
            ),
          });

          final response = await dio.post(
            'http://$receiverIp:$receiverPort/upload',
            data: formData,
            onSendProgress: (sent, total) {
              final progress = sent / total;
              onProgress(transferId, progress);

              // Calculate speed
              final now = DateTime.now();
              final timeDiff = now.difference(lastTime).inMilliseconds;
              double? speed;

              if (timeDiff > 500) {
                // Update speed every 500ms
                final bytesDiff = sent - lastSent;
                speed = (bytesDiff / timeDiff) * 1000; // bytes per second
                lastSent = sent;
                lastTime = now;
              }

              _transferProgressController.add(
                fileTransfer.copyWith(
                  progress: progress,
                  speedBytesPerSecond: speed,
                ),
              );
            },
          );

          // Verify the response
          if (response.statusCode == 200) {
            completed = true;
            debugPrint('File ${file.name} transferred successfully');

            // Mark as completed
            _transferProgressController.add(
              fileTransfer.copyWith(
                status: TransferStatus.completed,
                progress: 1.0,
                speedBytesPerSecond: 0,
              ),
            );
          } else {
            throw Exception('Server returned status ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Error sending file ${file.name}: $e');
          _transferProgressController.add(
            fileTransfer.copyWith(
              status: TransferStatus.failed,
              errorMessage: e.toString(),
            ),
          );
        } finally {
          // Close the dio client
          dio.close();

          // Ensure completion is marked if progress reached 100% but status wasn't updated
          if (!completed && fileTransfer.progress >= 0.99) {
            _transferProgressController.add(
              fileTransfer.copyWith(
                status: TransferStatus.completed,
                progress: 1.0,
                speedBytesPerSecond: 0,
              ),
            );
          }
        }
      }(); // Note the () to execute the async closure immediately

      transferFutures.add(transferFuture); // Add the running future to the list
    }

    // Now, await all transfers to complete concurrently
    try {
      await Future.wait(transferFutures);
      debugPrint('All ${files.length} file transfers completed');
    } catch (e) {
      debugPrint('Error in parallel transfers: $e');
      rethrow;
    }
  }

  /// Send transfer request to receiver
  Future<bool> sendTransferRequest({
    required String receiverIp,
    required int receiverPort,
    required String senderName,
    required List<FileMetadata> files,
  }) async {
    try {
      final dio = Dio();
      final request = TransferRequest(
        id: const Uuid().v4(),
        senderName: senderName,
        senderIp: await _getLocalIp(),
        port: _serverPort ?? 0,
        files: files,
      );

      final response = await dio.post(
        'http://$receiverIp:$receiverPort/request',
        data: json.encode(request.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending transfer request: $e');
      return false;
    }
  }

  Future<String> _getLocalIp() async {
    final networkInfo = NetworkInfo();
    final wifiIP = await networkInfo.getWifiIP();
    return wifiIP ?? '127.0.0.1';
  }

  Future<void> stopServer() async {
    await _httpServer?.close(force: true);
    _serverPort = null;
  }

  void dispose() {
    stopServer();
    _transferRequestController.close();
    _transferProgressController.close();
  }
}

// ============================================================================
// STATE MANAGEMENT (RIVERPOD)
// ============================================================================

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final service = DiscoveryService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

final fileTransferServiceProvider = Provider<FileTransferService>((ref) {
  final service = FileTransferService();
  ref.onDispose(() => service.dispose());
  return service;
});

final discoveredDevicesProvider = StreamProvider<DiscoveredDevice>((ref) {
  final service = ref.watch(discoveryServiceProvider);
  return service.deviceStream;
});

final transferRequestProvider = StreamProvider<TransferRequest>((ref) {
  final service = ref.watch(fileTransferServiceProvider);
  return service.transferRequestStream;
});

final transferProgressProvider = StreamProvider<FileTransfer>((ref) {
  final service = ref.watch(fileTransferServiceProvider);
  return service.transferProgressStream;
});

final isReceivingProvider = StateProvider<bool>((ref) => false);
final serverPortProvider = StateProvider<int?>((ref) => null);

// Receiving progress: Map of fileId to progress (0.0 to 1.0)
final receivingProgressProvider = StateProvider<Map<String, double>>(
  (ref) => {},
);

final deviceNameProvider = FutureProvider<String>((ref) async {
  final deviceInfo = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.model;
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      return windowsInfo.computerName;
    } else if (Platform.isLinux) {
      final linuxInfo = await deviceInfo.linuxInfo;
      return linuxInfo.prettyName;
    }
  } catch (e) {
    debugPrint('Error getting device name: $e');
  }
  return 'Unknown Device';
});

// ============================================================================
// UI COMPONENTS
// ============================================================================

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final Map<String, DiscoveredDevice> _devices = {};
  final List<FileTransfer> _activeTransfers = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final discoveryService = ref.read(discoveryServiceProvider);
    await discoveryService.startDiscovery();
  }

  @override
  Widget build(BuildContext context) {
    final isReceiving = ref.watch(isReceivingProvider);
    final deviceNameAsync = ref.watch(deviceNameProvider);

    // Listen to discovered devices
    ref.listen<AsyncValue<DiscoveredDevice>>(discoveredDevicesProvider, (
      _,
      next,
    ) {
      next.whenData((device) {
        setState(() {
          _devices[device.id] = device;
        });
      });
    });

    // Listen to transfer requests
    ref.listen<AsyncValue<TransferRequest>>(transferRequestProvider, (_, next) {
      next.whenData((request) {
        _showTransferRequestDialog(request);
      });
    });

    // Listen to transfer progress
    ref.listen<AsyncValue<FileTransfer>>(transferProgressProvider, (_, next) {
      next.whenData((transfer) {
        setState(() {
          final index = _activeTransfers.indexWhere((t) => t.id == transfer.id);
          if (index != -1) {
            _activeTransfers[index] = transfer;
          } else {
            _activeTransfers.add(transfer);
          }
        });
      });
    });

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  floating: true,
                  expandedHeight: 120,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Share',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00D9FF),
                          ),
                        ),
                        deviceNameAsync.when(
                          data: (name) => Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    // Receiving Toggle
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Text(
                            isReceiving ? 'Receiving' : 'Not Receiving',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Switch(
                            value: isReceiving,
                            onChanged: (value) => _toggleReceiving(value),
                            activeTrackColor: const Color(0xFF00D9FF),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Active Transfers Section
                if (_activeTransfers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Transfers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._activeTransfers.map(
                            (transfer) => _buildTransferCard(transfer),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Discovered Devices Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Nearby Devices',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _refreshDevices,
                              color: const Color(0xFF00D9FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_devices.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.devices_other,
                                    size: 64,
                                    color: Colors.white24,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No devices found',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Make sure other devices are on\nthe same Wi-Fi network',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...(_devices.values.map(
                            (device) => _buildDeviceCard(device, isMobile),
                          )),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectAndSendFiles,
        icon: const Icon(Icons.send),
        label: const Text('Send Files'),
        backgroundColor: const Color(0xFF00D9FF),
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildDeviceCard(DiscoveredDevice device, bool isMobile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectAndSendFilesToDevice(device),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Platform.isAndroid ? Icons.smartphone : Icons.computer,
                  color: const Color(0xFF00D9FF),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.ipAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferCard(FileTransfer transfer) {
    IconData statusIcon;
    Color statusColor;

    switch (transfer.status) {
      case TransferStatus.transferring:
        statusIcon = Icons.sync;
        statusColor = const Color(0xFF00D9FF);
        break;
      case TransferStatus.completed:
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case TransferStatus.failed:
        statusIcon = Icons.error;
        statusColor = Colors.red;
        break;
      default:
        statusIcon = Icons.schedule;
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.fileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${transfer.senderName} → ${transfer.receiverName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(transfer.progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    if (transfer.status == TransferStatus.transferring &&
                        transfer.speedBytesPerSecond != null &&
                        transfer.speedBytesPerSecond! > 0)
                      Text(
                        _formatSpeed(transfer.speedBytesPerSecond!),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (transfer.status == TransferStatus.transferring) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: transfer.progress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ],
            if (transfer.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                transfer.errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
    }
  }

  Future<void> _toggleReceiving(bool value) async {
    ref.read(isReceivingProvider.notifier).state = value;

    if (value) {
      final deviceName = await ref.read(deviceNameProvider.future);
      final transferService = ref.read(fileTransferServiceProvider);
      final discoveryService = ref.read(discoveryServiceProvider);

      final port = await transferService.startReceivingServer(deviceName);
      if (port != null) {
        ref.read(serverPortProvider.notifier).state = port;
        await discoveryService.startListening(port);
        await discoveryService.startDiscovery();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Now receiving files'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      final transferService = ref.read(fileTransferServiceProvider);
      final discoveryService = ref.read(discoveryServiceProvider);

      await transferService.stopServer();
      await discoveryService.stop();
      ref.read(serverPortProvider.notifier).state = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stopped receiving files')),
        );
      }
    }
  }

  Future<void> _refreshDevices() async {
    setState(() {
      _devices.clear();
    });

    final discoveryService = ref.read(discoveryServiceProvider);
    await discoveryService.stop();
    await discoveryService.startDiscovery();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Refreshing devices...')));
    }
  }

  Future<void> _selectAndSendFiles() async {
    if (_devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No devices available. Please wait for discovery.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show device selection dialog
    final device = await showDialog<DiscoveredDevice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Device'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _devices.values.map((device) {
              return ListTile(
                leading: Icon(
                  Platform.isAndroid ? Icons.smartphone : Icons.computer,
                  color: const Color(0xFF00D9FF),
                ),
                title: Text(device.name),
                subtitle: Text(device.ipAddress),
                onTap: () => Navigator.pop(context, device),
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (device != null) {
      await _selectAndSendFilesToDevice(device);
    }
  }

  Future<void> _selectAndSendFilesToDevice(DiscoveredDevice device) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false, // Don't load entire file into memory
      );

      if (result == null || result.files.isEmpty) return;

      final transferService = ref.read(fileTransferServiceProvider);
      final deviceName = await ref.read(deviceNameProvider.future);

      // Send transfer request first
      final files = result.files
          .map(
            (f) =>
                FileMetadata(name: f.name, size: f.size, mimeType: f.extension),
          )
          .toList();

      final requestSent = await transferService.sendTransferRequest(
        receiverIp: device.ipAddress,
        receiverPort: device.serverPort,
        senderName: deviceName,
        files: files,
      );

      if (!requestSent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send transfer request'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Wait for acceptance (in real implementation, you'd wait for a response)
      // For now, we'll proceed with the transfer

      await transferService.sendFiles(
        receiverIp: device.ipAddress,
        receiverPort: device.serverPort,
        files: result.files,
        senderName: deviceName,
        receiverName: device.name,
        onProgress: (fileId, progress) {
          debugPrint('File $fileId: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Files sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTransferRequestDialog(TransferRequest request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.senderName} wants to send you:'),
            const SizedBox(height: 12),
            ...request.files.map(
              (file) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      _formatBytes(file.size),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptTransfer(request);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptTransfer(TransferRequest request) async {
    // In a real implementation, you would send an acceptance message
    // and handle the incoming file transfer
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transfer accepted. Receiving files...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

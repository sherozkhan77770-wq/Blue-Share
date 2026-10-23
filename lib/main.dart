
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const BlueShareApp());
}

const blue = Color(0xFF1687FF);
const background = Color(0xFF080D18);
const panel = Color(0xFF151D2D);
const serviceId = 'com.example.blue_share';

class BlueShareApp extends StatelessWidget {
  const BlueShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const OfflineChatScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final String sender;
  final bool isMine;
  final DateTime time;
  final bool isFile;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.isMine,
    required this.time,
    this.isFile = false,
  });
}

class OfflineChatScreen extends StatefulWidget {
  const OfflineChatScreen({super.key});

  @override
  State<OfflineChatScreen> createState() => _OfflineChatScreenState();
}

class _OfflineChatScreenState extends State<OfflineChatScreen> {
  final Nearby _nearby = Nearby();
  final TextEditingController _messageController =
      TextEditingController();

  final String _userName =
      'BlueShare-${Random().nextInt(9000) + 1000}';

  final Map<String, String> _discovered = {};
  final Map<String, String> _endpointNames = {};
  final Set<String> _connected = {};
  final List<ChatMessage> _messages = [];

  final Map<int, String> _incomingNames = {};
  final Map<int, String> _incomingPaths = {};
  final Set<int> _completedFiles = {};
  final Set<int> _savingFiles = {};

  final Strategy _strategy = Strategy.P2P_CLUSTER;

  bool _advertising = false;
  bool _discovering = false;
  bool _busy = false;
  String _status = 'Connect to another nearby phone';

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<bool> _requestPermissions() async {
    try {
      final results = await <Permission>[
        Permission.locationWhenInUse,
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.nearbyWifiDevices,
      ].request();

      final required = <Permission>[
        Permission.locationWhenInUse,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ];

      final denied = required.any(
        (permission) => results[permission]?.isGranted != true,
      );

      if (denied) {
        _showMessage(
          'Bluetooth aur nearby permissions allow karein.',
        );
        return false;
      }

      return true;
    } catch (e) {
      _showMessage('Permission error: $e');
      return false;
    }
  }

  Future<void> _startAdvertising() async {
    if (_busy || _advertising) return;

    setState(() => _busy = true);

    try {
      if (!await _requestPermissions()) return;

      final started = await _nearby.startAdvertising(
        _userName,
        _strategy,
        serviceId: serviceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );

      if (!mounted) return;

      setState(() {
        _advertising = started;
        _status = started
            ? 'Phone is visible to nearby devices'
            : 'Could not make phone visible';
      });
    } catch (e) {
      _showMessage('Advertising error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startDiscovery() async {
    if (_busy || _discovering) return;

    setState(() => _busy = true);

    try {
      if (!await _requestPermissions()) return;

      final started = await _nearby.startDiscovery(
        _userName,
        _strategy,
        serviceId: serviceId,
        onEndpointFound: (id, name, foundService) {
          if (!mounted || foundService != serviceId) return;

          setState(() {
            _discovered[id] = name;
            _endpointNames[id] = name;
            _status = 'Found nearby phone: $name';
          });
        },
        onEndpointLost: (id) {
          if (!mounted || id == null) return;
          setState(() => _discovered.remove(id));
        },
      );

      if (!mounted) return;

      setState(() {
        _discovering = started;
        _status = started
            ? 'Searching for nearby phones...'
            : 'Could not start search';
      });
    } catch (e) {
      _showMessage('Search error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectTo(String id) async {
    try {
      await _nearby.requestConnection(
        _userName,
        id,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      _showMessage('Connection request sent');
    } catch (e) {
      _showMessage('Connection error: $e');
    }
  }

  Future<void> _onConnectionInitiated(
    String id,
    ConnectionInfo info,
  ) async {
    _endpointNames[id] = info.endpointName;

    if (!mounted) {
      await _nearby.rejectConnection(id);
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Connection request'),
        content: Text(
          '${info.endpointName} wants to connect.\n\n'
          'Verification code: ${info.authenticationToken}\n\n'
          'Accept only if you trust this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (accepted != true) {
      try {
        await _nearby.rejectConnection(id);
      } catch (_) {}
      return;
    }

    try {
      await _nearby.acceptConnection(
        id,
        onPayLoadRecieved: _onPayloadReceived,
        onPayloadTransferUpdate: _onPayloadTransferUpdate,
      );
    } catch (e) {
      _showMessage('Could not accept connection: $e');
    }
  }

  void _onConnectionResult(String id, Status status) {
    if (!mounted) return;

    final connected =
        status.toString().toUpperCase().contains('CONNECTED');

    setState(() {
      if (connected) {
        _connected.add(id);
        _status = 'Connected to ${_endpointNames[id] ?? 'phone'}';
      } else {
        _connected.remove(id);
        _status = 'Connection result: $status';
      }
    });

    _showMessage(
      connected ? 'Phone connected!' : 'Connection: $status',
    );
  }

  void _onDisconnected(String id) {
    if (!mounted) return;

    setState(() {
      _connected.remove(id);
      _status = 'Phone disconnected';
    });
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES &&
        payload.bytes != null) {
      try {
        final data = jsonDecode(
          utf8.decode(payload.bytes!),
        ) as Map<String, dynamic>;

        if (data['type'] == 'chat') {
          final text = (data['text'] ?? '').toString();
          final sender =
              (data['sender'] ?? 'Nearby phone').toString();

          if (text.isNotEmpty && mounted) {
            setState(() {
              _messages.add(
                ChatMessage(
                  text: text,
                  sender: sender,
                  isMine: false,
                  time: DateTime.now(),
                ),
              );
              _status = 'Message received';
            });
          }
        } else if (data['type'] == 'file_meta') {
          final id = data['payloadId'] as int?;
          final name = data['name']?.toString();

          if (id != null && name != null && name.isNotEmpty) {
            _incomingNames[id] = name;
            _saveIncomingFileIfReady(id);
          }
        }
      } catch (_) {
        // Ignore unknown byte payloads.
      }
      return;
    }

    if (payload.type == PayloadType.FILE) {
      final source = payload.uri ?? payload.filePath;
      if (source == null || source.isEmpty) return;

      _incomingPaths[payload.id] = source;
      _saveIncomingFileIfReady(payload.id);
    }
  }

  void _onPayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) {
    if (update.status == PayloadStatus.SUCCESS) {
      _completedFiles.add(update.id);
      _saveIncomingFileIfReady(update.id);
    } else if (update.status == PayloadStatus.FAILURE) {
      _showMessage('File transfer failed');
    }
  }

  Future<void> _saveIncomingFileIfReady(int id) async {
    if (!_completedFiles.contains(id) ||
        !_incomingNames.containsKey(id) ||
        !_incomingPaths.containsKey(id) ||
        _savingFiles.contains(id)) {
      return;
    }

    _savingFiles.add(id);

    try {
      final directory = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();

      final originalName = _incomingNames[id]!;
      final safeName = originalName
          .split(RegExp(r'[/\\]'))
          .last
          .replaceAll(RegExp(r'[<>:"|?*]'), '_');

      final destination =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final copied = await _nearby.copyFileAndDeleteOriginal(
        _incomingPaths[id]!,
        destination,
      );

      if (copied && mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'Received file: $safeName\nSaved in app storage.',
              sender: _endpointNames.values.isNotEmpty
                  ? _endpointNames.values.first
                  : 'Nearby phone',
              isMine: false,
              time: DateTime.now(),
              isFile: true,
            ),
          );
          _status = 'File received and saved';
        });
        _showMessage('File received: $safeName');
      } else {
        _showMessage('File received, but saving failed');
      }
    } catch (e) {
      _showMessage('Could not save received file: $e');
    } finally {
      _savingFiles.remove(id);
      _incomingPaths.remove(id);
      _incomingNames.remove(id);
      _completedFiles.remove(id);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_connected.isEmpty) {
      _showMessage('Connect to another phone first');
      return;
    }

    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': 'chat',
          'sender': _userName,
          'text': text,
        }),
      ),
    );

    try {
      for (final id in _connected.toList()) {
        await _nearby.sendBytesPayload(id, bytes);
      }

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: text,
            sender: _userName,
            isMine: true,
            time: DateTime.now(),
          ),
        );
        _status = 'Message sent';
      });

      _messageController.clear();
    } catch (e) {
      _showMessage('Message sending error: $e');
    }
  }

  Future<void> _chooseAndSendFile(FileType type) async {
    if (_connected.isEmpty) {
      _showMessage('File bhejne se pehle phone connect karein');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final path = file.path;

      if (path == null || !File(path).existsSync()) {
        _showMessage('Selected file ka path nahi mila');
        return;
      }

      if (file.size > 500 * 1024 * 1024) {
        _showMessage('Filhaal 500 MB se chhoti file select karein');
        return;
      }

      var sentToAnyDevice = false;

      for (final endpointId in _connected.toList()) {
        try {
          final payloadId = await _nearby.sendFilePayload(
            endpointId,
            path,
          );

          await _nearby.sendBytesPayload(
            endpointId,
            Uint8List.fromList(
              utf8.encode(
                jsonEncode({
                  'type': 'file_meta',
                  'payloadId': payloadId,
                  'name': file.name,
                }),
              ),
            ),
          );

          sentToAnyDevice = true;
        } catch (e) {
          _showMessage('Could not send to one phone: $e');
        }
      }

      if (!mounted) return;

      if (sentToAnyDevice) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'File sent: ${file.name}',
              sender: _userName,
              isMine: true,
              time: DateTime.now(),
              isFile: true,
            ),
          );
          _status = 'File transfer started';
        });

        _showMessage('File sending started: ${file.name}');
      }
    } catch (e) {
      _showMessage('File selection/sending error: $e');
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: blue),
              title: const Text('Send photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _chooseAndSendFile(FileType.image);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.video_library,
                color: blue,
              ),
              title: const Text('Send video'),
              onTap: () {
                Navigator.pop(sheetContext);
                _chooseAndSendFile(FileType.video);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: blue,
              ),
              title: const Text('Send any file'),
              onTap: () {
                Navigator.pop(sheetContext);
                _chooseAndSendFile(FileType.any);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disconnectAll() async {
    try {
      await _nearby.stopAllEndpoints();
    } catch (e) {
      _showMessage('Disconnect error: $e');
    }

    if (!mounted) return;

    setState(() {
      _connected.clear();
      _discovered.clear();
      _status = 'Disconnected';
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _nearby.stopDiscovery();
    _nearby.stopAdvertising();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bluetooth_connected, color: blue),
            SizedBox(width: 10),
            Text(
              'BlueShare',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Disconnect',
            onPressed: _disconnectAll,
            icon: const Icon(Icons.link_off),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF26364D),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OFFLINE CONNECTION',
                    style: TextStyle(
                      color: blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                  const SizedBox(height: 6),
                  Text(
                    'Your device: $_userName',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy || _advertising
                            ? null
                            : _startAdvertising,
                        icon: const Icon(Icons.wifi_tethering),
                        label: const Text('Make visible'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _busy || _discovering
                            ? null
                            : _startDiscovery,
                        icon: const Icon(Icons.search),
                        label: const Text('Find phones'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connected phones: ${_connected.length}',
                    style: const TextStyle(
                      color: Colors.lightGreenAccent,
                    ),
                  ),
                ],
              ),
            ),
            if (_discovered.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: _discovered.entries.map((entry) {
                    final connected = _connected.contains(entry.key);

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF183A68),
                        child: Icon(Icons.phone_android),
                      ),
                      title: Text(entry.value),
                      subtitle: Text(
                        connected ? 'Connected' : 'T

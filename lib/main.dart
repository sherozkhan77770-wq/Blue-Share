
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const BlueShareApp());
}

class BlueShareApp extends StatelessWidget {
  const BlueShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080D18),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1687FF),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF080D18),
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF151D2D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
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

  ChatMessage({
    required this.text,
    required this.sender,
    required this.isMine,
    required this.time,
  });
}

class OfflineChatScreen extends StatefulWidget {
  const OfflineChatScreen({super.key});

  @override
  State<OfflineChatScreen> createState() => _OfflineChatScreenState();
}

class _OfflineChatScreenState extends State<OfflineChatScreen> {
  final Nearby _nearby = Nearby();
  final TextEditingController _messageController = TextEditingController();

  final String _userName =
      'BlueShare-${Random().nextInt(9000) + 1000}';

  final Map<String, String> _discovered = {};
  final Map<String, String> _endpointNames = {};
  final Set<String> _connected = {};
  final List<ChatMessage> _messages = [];

  final Strategy _strategy = Strategy.P2P_CLUSTER;

  bool _advertising = false;
  bool _discovering = false;
  bool _busy = false;
  String _status = 'Connect to another nearby phone';

  static const String _serviceId = 'com.example.blue_share';

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _requestPermissions() async {
    try {
      final permissions = <Permission>[
        Permission.locationWhenInUse,
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.nearbyWifiDevices,
      ];

      final results = await permissions.request();
      final denied = results.entries
          .where((entry) => entry.value.isDenied || entry.value.isPermanentlyDenied)
          .map((entry) => entry.key.toString())
          .toList();

      if (denied.isNotEmpty) {
        _showMessage(
          'Some permissions are missing. Allow nearby/Bluetooth permissions in Settings.',
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
    _busy = true;

    try {
      if (!await _requestPermissions()) return;

      final started = await _nearby.startAdvertising(
        _userName,
        _strategy,
        serviceId: _serviceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );

      if (!mounted) return;
      setState(() {
        _advertising = started;
        _status = started
            ? 'Your phone is visible to nearby devices'
            : 'Could not start advertising';
      });
    } catch (e) {
      _showMessage('Could not make your phone discoverable: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _startDiscovery() async {
    if (_busy || _discovering) return;
    _busy = true;

    try {
      if (!await _requestPermissions()) return;

      final started = await _nearby.startDiscovery(
        _userName,
        _strategy,
        serviceId: _serviceId,
        onEndpointFound: (id, name, serviceId) {
          if (!mounted || id == _userName) return;
          setState(() {
            _discovered[id] = name;
            _endpointNames[id] = name;
            _status = 'Found nearby device: $name';
          });
        },
        onEndpointLost: (id) {
          if (!mounted) return;
          setState(() {
            _discovered.remove(id);
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _discovering = started;
        _status = started
            ? 'Searching for nearby BlueShare phones…'
            : 'Could not start device search';
      });
    } catch (e) {
      _showMessage('Device search failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _stopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
      if (!mounted) return;
      setState(() {
        _discovering = false;
        _status = 'Device search stopped';
      });
    } catch (e) {
      _showMessage('Could not stop search: $e');
    }
  }

  Future<void> _stopAdvertising() async {
    try {
      await _nearby.stopAdvertising();
      if (!mounted) return;
      setState(() {
        _advertising = false;
        _status = 'Your phone is no longer advertising';
      });
    } catch (e) {
      _showMessage('Could not stop advertising: $e');
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
      _showMessage('Could not request connection: $e');
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
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151D2D),
          title: const Text('Connection request'),
          content: Text(
            '${info.endpointName} wants to connect.\n\n'
            'Verification code: ${info.authenticationToken}\n\n'
            'Only accept if you trust the other phone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Accept'),
            ),
          ],
        );
      },
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
        onPayloadTransferUpdate: (endpointId, update) {},
      );

      if (mounted) {
        setState(() {
          _status = 'Accepted connection with ${info.endpointName}';
        });
      }
    } catch (e) {
      _showMessage('Could not accept connection: $e');
    }
  }

  void _onConnectionResult(String id, Status status) {
    if (!mounted) return;

    final statusText = status.toString();
    final connected = statusText.toUpperCase().contains('CONNECTED');

    setState(() {
      if (connected) {
        _connected.add(id);
        _status = 'Connected to ${_endpointNames[id] ?? 'nearby phone'}';
      } else {
        _connected.remove(id);
        _status = 'Connection result: $statusText';
      }
    });

    _showMessage(
      connected ? 'Phone connected successfully!' : 'Connection: $statusText',
    );
  }

  void _onDisconnected(String id) {
    if (!mounted) return;

    setState(() {
      _connected.remove(id);
      _status = '${_endpointNames[id] ?? 'Phone'} disconnected';
    });

    _showMessage('Device disconnected');
  }

  void _onPayloadReceived(String id, Payload payload) {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) {
      return;
    }

    try {
      final decoded = utf8.decode(payload.bytes!);
      final data = jsonDecode(decoded) as Map<String, dynamic>;

      if (data['type'] != 'chat') return;

      final sender = (data['sender'] ?? 'Nearby phone').toString();
      final text = (data['text'] ?? '').toString();

      if (text.isEmpty || !mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: text,
            sender: sender,
            isMine: false,
            time: DateTime.now(),
          ),
        );
        _status = 'Message received from $sender';
      });
    } catch (_) {
      // Ignore payloads that are not BlueShare chat messages.
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    if (_connected.isEmpty) {
      _showMessage('Connect to another phone before sending messages');
      return;
    }

    final payload = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': 'chat',
          'sender': _userName,
          'text': text,
          'time': DateTime.now().toIso8601String(),
        }),
      ),
    );

    final failed = <String>[];

    for (final id in _connected.toList()) {
      try {
        await _nearby.sendBytesPayload(id, payload);
      } catch (_) {
        failed.add(id);
      }
    }

    if (!mounted) return;

    if (failed.isNotEmpty) {
      _showMessage('Some messages could not be sent');
    }

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
      _status = 'Disconnected from nearby phones';
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bluetooth_connected, color: Color(0xFF1687FF)),
            SizedBox(width: 10),
            Text(
              'BlueShare',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Disconnect all',
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
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF151D2D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF26364D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OFFLINE CONNECTION',
                    style: TextStyle(
                      color: Color(0xFF1687FF),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                  const SizedBox(height: 6),
                  Text(
                    'Your device: $_userName',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            _advertising || _busy ? null : _startAdvertising,
                        icon: const Icon(Icons.wifi_tethering),
                        label: const Text('Make visible'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed:
                            _discovering || _busy ? null : _startDiscovery,
                        icon: const Icon(Icons.search),
                        label: const Text('Find phones'),
                      ),
                      if (_advertising)
                        OutlinedButton(
                          onPressed: _stopAdvertising,
                          child: const Text('Stop visible'),
                        ),
                      if (_discovering)
                        OutlinedButton(
                          onPressed: _stopDiscovery,
                          child: const Text('Stop search'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connected phones: ${_connected.length}',
                    style: const TextStyle(color: Colors.lightGreenAccent),
                  ),
                ],
              ),
            ),
            if (_discovered.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101827),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nearby devices',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ..._discovered.entries.map((entry) {
                      final connected = _connected.contains(entry.key);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF183A68),
                          child: Icon(Icons.phone_android),
                        ),
                        title: Text(entry.value),
                        subtitle: Text(
                          connected ? 'Connected' : 'Tap to connect',
                        ),
                        trailing: connected
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.lightGreenAccent,
                              )
                            : IconButton(
                                onPressed: () => _connectTo(entry.key),
                                icon: const Icon(
                                  Icons.link,
                                  color: Color(0xFF1687FF),
                                ),
                              ),
                      );
                    }),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 52,
                              color: Color(0xFF1687FF),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Connect two phones, then send your first message.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return Align(
                          alignment: message.isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78,
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: message.isMine
                                  ? const Color(0xFF1265C7)
                                  : const Color(0xFF1B2638),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!message.isMine)
                                  Text(
                                    message.sender,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.lightBlueAccent,
                                    ),
                                  ),
                                Text(message.text),
                                const SizedBox(height: 4),
                                Text(
                                  '${message.time.hour.toString().padLeft(2, '0')}:'
                                  '${message.time.minute.toString

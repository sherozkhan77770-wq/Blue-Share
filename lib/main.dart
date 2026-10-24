import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const String serviceId = 'com.example.blue_share';
const Strategy nearbyStrategy = Strategy.P2P_CLUSTER;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BlueShareApp());
}

class BlueShareApp extends StatelessWidget {
  const BlueShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blue-Share',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080B12),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF168BFF),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF080B12),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF080B12),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return const HomePage();
        return const PhoneLoginPage();
      },
    );
  }
}

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _sendingCode = false;
  bool _verifyingCode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1268C4),
      ),
    );
  }

  Future<void> _sendCode() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      _showMessage(
        'Enter your phone number with country code, e.g. +923001234567',
      );
      return;
    }
    if (!rawPhone.startsWith('+') || rawPhone.length < 8) {
      _showMessage('Use international format, e.g. +923001234567');
      return;
    }

    setState(() => _sendingCode = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: rawPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
          } catch (e) {
            _showMessage('Automatic verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _showMessage(
            e.message ??
                'Could not send verification code. Check Firebase settings.',
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _verificationId = verificationId);
          _showMessage('Verification code sent by SMS');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      _showMessage('Could not start phone verification: $e');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _verifyCode() async {
    final verificationId = _verificationId;
    final smsCode = _otpController.text.trim();
    if (verificationId == null) {
      _showMessage('First request an SMS code');
      return;
    }
    if (smsCode.length < 4) {
      _showMessage('Enter the SMS verification code');
      return;
    }

    setState(() => _verifyingCode = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // AuthGate automatically opens HomePage after successful sign-in.
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Invalid verification code');
    } catch (e) {
      _showMessage('Could not verify code: $e');
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.share,
                    size: 72,
                    color: Colors.lightBlueAccent,
                  ),                  const SizedBox(height: 16),
                  const Text(
                    'Blue-Share',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in with your phone number',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '+923001234567',
                      prefixIcon: Icon(Icons.phone_android),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _sendingCode ? null : _sendCode,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _sendingCode
                            ? 'Sending code...'
                            : 'Send verification code',
                      ),
                    ),
                  ),
                  if (_verificationId != null) ...[
                    const SizedBox(height: 24),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'SMS verification code',
                        prefixIcon: Icon(Icons.password),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _verifyingCode ? null : _verifyCode,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _verifyingCode
                              ? 'Verifying...'
                              : 'Verify and log in',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Enter your number with country code, for example +92 for Pakistan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.mine,
    this.filePath,
    this.fileName,
  });

  final String text;
  final bool mine;
  final String? filePath;
  final String? fileName;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Nearby nearby = Nearby();
  final TextEditingController messageController = TextEditingController();
  final List<ChatMessage> messages = [];
  final Map<String, String> devices = {};
  final Set<int> completedFiles = {};
  final Map<int, String> incomingUris = {};
  final Map<int, String> incomingNames = {};
  final Map<int, String> outgoingNames = {};

  String? connectedEndpointId;
  String? connectedEndpointName;
  String statusText = 'Not connected';
  bool isAdvertising = false;
  bool isDiscovering = false;
  bool busy = false;
  int selectedTab = 0;

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final permissions = <Permission>[
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
      Permission.storage,
      Permission.photos,
      Permission.videos,
    ];

    for (final permission in permissions) {
      try {
        await permission.request();
      } catch (_) {
        // Some Android versions do not expose every permission.
      }
    }

    // Nearby Connections may work with different permission sets on
    // different Android versions. Continue and let the plugin report errors.
    return true;
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: const Color(0xFF1268C4),
      ),
    );
  }

  Future<void> _startAdvertising() async {
    if (busy) return;
    setState(() {
      busy = true;
      statusText = 'Making this phone visible...';
    });

    try {
      await _requestPermissions();
      await nearby.startAdvertising(
        'BlueShare-${Platform.isAndroid ? 'Android' : 'Device'}',
        nearbyStrategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: serviceId,
      );
      if (!mounted) return;
      setState(() {
        isAdvertising = true;
        statusText = 'This phone is visible to nearby devices';
      });
      _showMessage('Phone is now visible');
    } catch (e) {
      _showMessage('Could not make phone visible: $e');
      setState(() => statusText = 'Could not start visibility');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _startDiscovery() async {
    if (busy) return;
    setState(() {
      busy = true;
      statusText = 'Searching for nearby phones...';
            devices.clear();
    });

    try {
      await _requestPermissions();
      await nearby.startDiscovery(
        'BlueShare-${Platform.isAndroid ? 'Android' : 'Device'}',
        nearbyStrategy,
        onEndpointFound: (id, name, serviceId) {
          if (!mounted) return;
          setState(() {
            devices[id] = name;
            statusText = 'Found ${devices.length} nearby device(s)';
          });
        },
        onEndpointLost: (id) {
          if (!mounted) return;
          setState(() => devices.remove(id));
        },
        serviceId: serviceId,
      );
      if (!mounted) return;
      setState(() => isDiscovering = true);
      _showMessage('Searching for nearby devices');
    } catch (e) {
      _showMessage('Could not search for devices: $e');
      setState(() => statusText = 'Search could not start');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _connectToDevice(String id, String name) async {
    try {
      await nearby.requestConnection(
        'BlueShare',
        id,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      _showMessage('Connection request sent to $name');
    } catch (e) {
      _showMessage('Connection request failed: $e');
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Connection request'),
        content: Text(
          '${info.endpointName} wants to connect to Blue-Share.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await nearby.rejectConnection(id);
              } catch (_) {}
            },
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await nearby.acceptConnection(
                  id,
                  onPayLoadRecieved: _onPayloadReceived,
                  onPayloadTransferUpdate: _onPayloadTransferUpdate,
                );
              } catch (e) {
                _showMessage('Could not accept connection: $e');
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _onConnectionResult(String id, Status status) {
    if (!mounted) return;
    setState(() {
      if (status == Status.CONNECTED) {
        connectedEndpointId = id;
        connectedEndpointName = devices[id] ?? 'Nearby phone';
        statusText = 'Connected to $connectedEndpointName';
      } else {
        statusText = 'Connection status: $status';
      }
    });
    _showMessage(
      status == Status.CONNECTED
          ? 'Connected successfully'
          : 'Connection result: $status',
    );
  }

  void _onDisconnected(String id) {
    if (!mounted) return;
    setState(() {
      if (connectedEndpointId == id) {
        connectedEndpointId = null;
        connectedEndpointName = null;
      }
      statusText = 'Device disconnected';
    });
    _showMessage('Nearby phone disconnected');
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final text = utf8.decode(payload.bytes!);
      if (text.startsWith('__BS_FILE__:')) {
        try {
          final data = jsonDecode(
            text.substring('__BS_FILE__:'.length),
          ) as Map<String, dynamic>;
          final id = (data['id'] as num).toInt();
          incomingNames[id] =
              (data['name'] as String?) ?? 'Received file';
          _finishIncomingFile(id);
        } catch (_) {
          _showMessage('Received file information could not be read');
        }
      } else {
        if (!mounted) return;
        setState(() {
          messages.add(ChatMessage(text: text, mine: false));
        });
      }
    } else if (payload.type == PayloadType.FILE) {
      final uri = payload.uri;
      if (uri != null) {
        incomingUris[payload.id] = uri;
        _finishIncomingFile(payload.id);
      }
    }
  }

  void _onPayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) {
    if (update.status == PayloadStatus.SUCCESS) {
      completedFiles.add(update.id);
      _finishIncomingFile(update.id);
    } else if (update.status == PayloadStatus.FAILURE) {
      _showMessage('File transfer failed');
    }
  }

  Future<void> _finishIncomingFile(int id) async {
    final uri = incomingUris[id];
    final name = incomingNames[id];
    if (uri == null || name == null || !completedFiles.contains(id)) return;

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        _showMessage('Could not find a folder to save the file');
        return;
      }
      final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final destination = File('${directory.path}/$safeName');
      await File.fromUri(Uri.parse(uri)).copy(destination.path);

      if (!mounted) return;
      setState(() {
        messages.add(ChatMessage(
          text: 'File received and saved',
          mine: false,
          filePath: destination.path,
          fileName: safeName,
        ));
      });
      _showMessage('File saved to ${destination.path}');
      incomingUris.remove(id);
      incomingNames.remove(id);
      completedFiles.remove(id);    } catch (e) {
      _showMessage('Could not save received file: $e');
    }
  }

  Future<void> _sendText() async {
    final text = messageController.text.trim();
    final endpointId = connectedEndpointId;
    if (text.isEmpty) return;
    if (endpointId == null) {
      _showMessage('First connect to another phone');
      return;
    }

    try {
      await nearby.sendBytesPayload(endpointId, utf8.encode(text));
      if (!mounted) return;
      setState(() => messages.add(ChatMessage(text: text, mine: true)));
      messageController.clear();
    } catch (e) {
      _showMessage('Message could not be sent: $e');
    }
  }

  Future<void> _sendFile() async {
    final endpointId = connectedEndpointId;
    if (endpointId == null) {
      _showMessage('First connect to another phone');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final path = picked.path;
      if (path == null) {
        _showMessage('Could not access the selected file');
        return;
      }

      final payloadId = await nearby.sendFilePayload(endpointId, path);
      outgoingNames[payloadId] = picked.name;
      await nearby.sendBytesPayload(
        endpointId,
        utf8.encode('__BS_FILE__:${jsonEncode({
          'id': payloadId,
          'name': picked.name,
        })}'),
      );

      if (!mounted) return;
      setState(() {
        messages.add(ChatMessage(
          text: 'Sending file...',
          mine: true,
          filePath: path,
          fileName: picked.name,
        ));
      });
      _showMessage('Sending ${picked.name}');
    } catch (e) {
      _showMessage('Could not send file: $e');
    }
  }

  Future<void> _stopNearby() async {
    try {
      await nearby.stopAdvertising();
    } catch (_) {}
    try {
      await nearby.stopDiscovery();
    } catch (_) {}
    try {
      await nearby.stopAllEndpoints();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      isAdvertising = false;
      isDiscovering = false;
      connectedEndpointId = null;
      connectedEndpointName = null;
      statusText = 'Not connected';
    });
  }

  Widget _buildChats() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF101827),
          child: Row(
            children: [
              const Icon(
                Icons.circle,
                color: Colors.blueAccent,
                size: 10,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connectedEndpointName == null
                      ? statusText
                      : 'Connected: $connectedEndpointName',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 54,
                        color: Colors.blueGrey,
                      ),
                      SizedBox(height: 12),
                      Text('No messages yet'),
                      SizedBox(height: 4),
                      Text(
                        'Connect to a nearby phone to start chatting',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final item = messages[index];
                    return Align(
                      alignment: item.mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.mine
                              ? const Color(0xFF075EBD)
                              : const Color(0xFF172033),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.text),
                            if (item.fileName != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(child: Text(item.fileName!)),
                                ],
                              ),
                            ],
                            if (item.filePath != null &&
                                item.fileName != null &&
                                !item.text.startsWith('Sending')) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.filePath!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sendFile,
                  icon: const Icon(
                    Icons.attach_file,
                    color: Colors.lightBlue,
                  ),
                  tooltip: 'Send file',
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      filled: true,
                      fillColor: const Color(0xFF141C2B),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _sendText,
                  icon: const Icon(
                    Icons.send,
                    color: Colors.lightBlue,
                  ),
                  tooltip: 'Send message',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevices() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(statusText, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : _startAdvertising,
          icon: const Icon(Icons.visibility),
          label: const Text('Be visible'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: busy ? null : _startDiscovery,
          icon: const Icon(Icons.search),
          label: const Text('Find devices'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _stopNearby,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Stop / Disconnect'),
        ),
        const SizedBox(height: 22),
        const Text(
          'Nearby devices',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (devices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No devices found yet. On the other phone, tap “Be visible”.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ...devices.entries.map(
          (entry) => Card(
            color: const Color(0xFF121A29),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF123F70),
                child: Icon(
                  Icons.phone_android,
                  color: Colors.lightBlue,
                ),
              ),
              title: Text(entry.value),
              subtitle: const Text('Nearby device'),
              trailing: FilledButton(
                onPressed: () => _connectToDevice(entry.key, entry.value),
                child: const Text('Connect'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(
    String title,
    IconData icon,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: Colors.blueAccent),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildChats(),
      _buildDevices(),
      _buildPlaceholder(
        'Status',
        Icons.circle_outlined,
        'Status feature is not implemented yet.',
      ),
      _buildPlaceholder(
        'Calls',
        Icons.call_outlined,
        'Voice calls are not implemented yet. Video calls are not included.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.share, color: Colors.lightBlue),
            SizedBox(width: 10),
            Text(
              'Blue-Share',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _stopNearby,
            icon: const Icon(Icons.link_off),
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: pages[selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.circle_outlined),
            label: 'Status',
          ),
          NavigationDestination(
            icon: Icon(Icons.call),
            label: 'Calls',
          ),
        ],
      ),
    );
  }
                                              }

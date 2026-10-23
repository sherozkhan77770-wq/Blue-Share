
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const BlueShareApp());
}

const Color blue = Color(0xFF1687FF);
const Color background = Color(0xFF080D16);
const Color panel = Color(0xFF111A29);
const String serviceId = 'com.blueshare.offline';

class ChatMessage {
  final String text;
  final bool isMine;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isMine,
    required this.time,
  });
}

class BlueShareApp extends StatelessWidget {
  const BlueShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BlueShare',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;
  bool busy = false;
  String connectionStatus = 'Not connected';

  final TextEditingController nameController =
      TextEditingController(text: 'BlueShare user');
  final TextEditingController messageController =
      TextEditingController();

  final List<ChatMessage> messages = [];
  final Map<String, String> discoveredDevices = {};
  final Set<String> connectedDevices = {};

  @override
  void dispose() {
    nameController.dispose();
    messageController.dispose();
    Nearby().stopDiscovery();
    Nearby().stopAdvertising();
    super.dispose();
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<bool> requestPermissions() async {
    try {
      final permissions = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
        Permission.nearbyWifiDevices,
      ];

      final results = await permissions.request();

      final bluetoothGranted =
          results[Permission.bluetoothScan]?.isGranted == true &&
          results[Permission.bluetoothAdvertise]?.isGranted == true &&
          results[Permission.bluetoothConnect]?.isGranted == true;

      final locationGranted =
          results[Permission.locationWhenInUse]?.isGranted == true;

      final wifiGranted =
          results[Permission.nearbyWifiDevices]?.isGranted == true;

      if (bluetoothGranted || locationGranted || wifiGranted) {
        return true;
      }

      showMessage(
        'Bluetooth/Nearby permissions allow karein, phir dobara try karein.',
      );
      return false;
    } catch (e) {
      showMessage('Permission error: $e');
      return false;
    }
  }

  void handleConnection(String endpointId) {
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (id, payload) {
        if (payload.type != PayloadType.BYTES ||
            payload.bytes == null) {
          return;
        }

        try {
          final decoded = utf8.decode(payload.bytes!);
          final data = jsonDecode(decoded) as Map<String, dynamic>;

          if (data['type'] == 'message') {
            final text = data['text'] as String? ?? '';

            if (text.isNotEmpty && mounted) {
              setState(() {
                messages.add(
                  ChatMessage(
                    text: text,
                    isMine: false,
                    time: DateTime.now(),
                  ),
                );
              });
            }
          }
        } catch (_) {
          showMessage('Received message read nahi ho saka.');
        }
      },
      onPayloadTransferUpdate: (id, update) {},
    );
  }

  Future<void> startAdvertising() async {
    if (!await requestPermissions()) return;

    setState(() {
      busy = true;
      connectionStatus = 'Making phone visible...';
    });

    try {
      await Nearby().stopDiscovery();

      final started = await Nearby().startAdvertising(
        nameController.text.trim().isEmpty
            ? 'BlueShare user'
            : nameController.text.trim(),
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: (id, info) {
          handleConnection(id);
        },
        onConnectionResult: (id, status) {
          if (!mounted) return;

          setState(() {
            if (status == Status.CONNECTED) {
              connectedDevices.add(id);
              connectionStatus = 'Phone connected';
            } else {
              connectionStatus = 'Connection result: $status';
            }
          });
        },
        onDisconnected: (id) {
          if (!mounted) return;

          setState(() {
            connectedDevices.remove(id);
            connectionStatus = 'Phone disconnected';
          });
        },
        serviceId: serviceId,
      );

      if (mounted) {
        setState(() {
          connectionStatus = started
              ? 'Phone visible — waiting for connection'
              : 'Could not make phone visible';
        });
      }
    } catch (e) {
      showMessage('Advertising error: $e');
      if (mounted) {
        setState(() {
          connectionStatus = 'Could not make phone visible';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> startDiscovery() async {
    if (!await requestPermissions()) return;

    setState(() {
      busy = true;
      discoveredDevices.clear();
      connectionStatus = 'Searching for nearby phones...';
    });

    try {
      await Nearby().stopAdvertising();

      final started = await Nearby().startDiscovery(
        nameController.text.trim().isEmpty
            ? 'BlueShare user'
            : nameController.text.trim(),
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, foundServiceId) {
          if (!mounted || foundServiceId != serviceId) return;

          setState(() {
            discoveredDevices[id] = name;
          });
        },
        onEndpointLost: (id) {
          if (!mounted || id == null) return;

          setState(() {
            discoveredDevices.remove(id);
          });
        },
        serviceId: serviceId,
      );

      if (mounted) {
        setState(() {
          connectionStatus = started
              ? 'Searching for nearby phones...'
              : 'Could not start search';
        });
      }
    } catch (e) {
      showMessage('Discovery error: $e');
      if (mounted) {
        setState(() {
          connectionStatus = 'Search failed';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> connectToDevice(String endpointId) async {
    if (!await requestPermissions()) return;

    setState(() {
      busy = true;
      connectionStatus = 'Connecting...';
    });

    try {
      await Nearby().requestConnection(
        nameController.text.trim().isEmpty
            ? 'BlueShare user'
            : nameController.text.trim(),
        endpointId,
        onConnectionInitiated: (id, info) {
          handleConnection(id);
        },
        onConnectionResult: (id, status) {
          if (!mounted) return;

          setState(() {
            if (status == Status.CONNECTED) {
              connectedDevices.add(id);
              connectionStatus = 'Phone connected';
              selectedTab = 0;
            } else {
              connectionStatus = 'Connection result: $status';
            }
          });
        },
        onDisconnected: (id) {
          if (!mounted) return;

          setState(() {
            connectedDevices.remove(id);
            connectionStatus = 'Phone disconnected';
          });
        },
      );
    } catch (e) {
      showMessage('Connection error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty) return;

    if (connectedDevices.isEmpty) {
      showMessage('Pehle Nearby tab se doosra phone connect karein.');
      return;
    }

    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': 'message',
          'text': text,
        }),
      ),
    );

    try {
      for (final endpointId in connectedDevices) {
        await Nearby().sendBytesPayload(endpointId, bytes);
      }

      if (!mounted) return;

      setState(() {
        messages.add(
          ChatMessage(
            text: text,
            isMine: true,
            time: DateTime.now(),
          ),
        );

        messageController.clear();
      });
    } catch (e) {
      showMessage('Message send nahi hua: $e');
    }
  }

  Widget buildChatPage() {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: blue,
                          size: 60,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Welcome to BlueShare',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Offline chat ke liye Nearby tab se doosra phone connect karein.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];

                    return Align(
                      alignment: message.isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 300,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message.isMine ? blue : panel,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(message.text),
                            const SizedBox(height: 4),
                            Text(
                              '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  onSubmitted: (_) => sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Write a message...',
                    filled: true,
                    fillColor: panel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: sendMessage,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildNearbyPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(
          Icons.bluetooth_searching,
          size: 62,
          color: blue,
        ),
        const SizedBox(height: 12),
        const Text(
          'Connect nearby devices',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          connectionStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Your device name',
            filled: true,
            fillColor: panel,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : startAdvertising,
          icon: const Icon(Icons.visibility),
          label: const Text('Make this phone visible'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : startDiscovery,
          icon: const Icon(Icons.search),
          label: const Text('Find nearby phones'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Found devices',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (discoveredDevices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Abhi koi phone nahi mila. Doosre phone par Make this phone visible dabayein.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ...discoveredDevices.entries.map(
          (entry) => Card(
            color: panel,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: blue,
                child: Icon(Icons.phone_android),
              ),
              title: Text(entry.value),
              subtitle: const Text('Nearby device'),
              trailing: const Icon(Icons.link, color: blue),
              onTap: busy
                  ? null
                  : () => connectToDevice(entry.key),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildPlaceholder(
    IconData icon,
    String title,
    String description,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: blue),
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
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSelectedPage() {
    switch (selectedTab) {
      case 0:
        return buildChatPage();
      case 1:
        return buildPlaceholder(
          Icons.circle_outlined,
          'Status',
          'Status sharing abhi implement nahi hui.',
        );
      case 2:
        return buildPlaceholder(
          Icons.call_outlined,
          'Calls',
          'Voice aur video calls abhi implement nahi hui.',
        );
      case 3:
        return buildNearbyPage();
      default:
        return buildPlaceholder(
          Icons.settings_outlined,
          'Settings',
          'BlueShare settings',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Chats',
      'Status',
      'Calls',
      'Nearby',
      'Settings',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.wifi_tethering, color: blue, size: 30),
            SizedBox(width: 10),
            Text(
              'BlueShare',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => selectedTab = 3),
            icon: const Icon(Icons.devices, color: blue),
            tooltip: 'Nearby devices',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF123D77),
                  panel,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay connected.',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Chat and share with people nearby.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(tabs.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(tabs[index]),
                    selected: selectedTab == index,
                    selectedColor: blue,
                    onSelected: (_) {
                      setState(() => selectedTab = index);
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: buildSelectedPage()),
        ],
      ),
    );
  }
}

  

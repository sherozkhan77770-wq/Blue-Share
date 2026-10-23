
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

const blue = Color(0xFF1687FF);
const bg = Color(0xFF080B12);
const panel = Color(0xFF121722);
const serviceId = 'com.example.blue_share';

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
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.dark(primary: blue),
        appBarTheme: const AppBarTheme(backgroundColor: bg),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool mine;
  ChatMessage(this.text, this.mine);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  bool busy = false;
  final nameController = TextEditingController(text: 'BlueShare User');
  final messageController = TextEditingController();
  final messages = <ChatMessage>[];
  final devices = <String, String>{};
  final connected = <String, String>{};

  void notify(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<bool> askPermissions() async {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();

    final denied = results.values.any(
      (status) => status.isDenied || status.isPermanentlyDenied,
    );

    if (denied) {
      notify('Bluetooth aur nearby permissions allow karo.');
      return false;
    }
    return true;
  }

  Future<void> startAdvertising() async {
    if (!await askPermissions()) return;

    try {
      final started = await Nearby().startAdvertising(
        nameController.text.trim().isEmpty
            ? 'BlueShare User'
            : nameController.text.trim(),
        Strategy.P2P_CLUSTER,
        serviceId: serviceId,
        onConnectionInitiated: (id, info) {
          askToAccept(id, info.endpointName);
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            setState(() {
              connected[id] = devices[id] ?? 'Connected device';
              devices.remove(id);
            });
            notify('Phone connect ho gaya!');
          } else {
            notify('Connection result: $status');
          }
        },
        onDisconnected: (id) {
          setState(() => connected.remove(id));
          notify('Device disconnect ho gaya.');
        },
      );

      notify(started
          ? 'Aapka phone ab doosre phone ko nazar aa sakta hai.'
          : 'Advertising shuru nahi ho saki.');
    } catch (e) {
      notify('Advertising error: $e');
    }
  }

  Future<void> startDiscovery() async {
    if (!await askPermissions()) return;

    try {
      final started = await Nearby().startDiscovery(
        nameController.text.trim().isEmpty
            ? 'BlueShare User'
            : nameController.text.trim(),
        Strategy.P2P_CLUSTER,
        serviceId: serviceId,
        onEndpointFound: (id, deviceName, foundServiceId) {
          if (!mounted || connected.containsKey(id)) return;

          setState(() => devices[id] = deviceName);
          notify('Phone mila: $deviceName');

          Nearby().requestConnection(
            nameController.text.trim().isEmpty
                ? 'BlueShare User'
                : nameController.text.trim(),
            id,
            onConnectionInitiated: (endpointId, info) {
              askToAccept(endpointId, info.endpointName);
            },
            onConnectionResult: (endpointId, status) {
              if (status == Status.CONNECTED) {
                setState(() {
                  connected[endpointId] = devices[endpointId] ??
                      'Connected device';
                  devices.remove(endpointId);
                });
                notify('Phone connect ho gaya!');
              } else {
                notify('Connection result: $status');
              }
            },
            onDisconnected: (endpointId) {
              setState(() => connected.remove(endpointId));
              notify('Device disconnect ho gaya.');
            },
          );
        },
        onEndpointLost: (id) {
          if (mounted) setState(() => devices.remove(id));
        },
      );

      notify(started
          ? 'Doosra BlueShare phone dhoondh rahe hain...'
          : 'Discovery shuru nahi ho saki.');
    } catch (e) {
      notify('Discovery error: $e');
    }
  }

  Future<void> askToAccept(String id, String deviceName) async {
    if (!mounted) return;

    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connection request'),
        content: Text('$deviceName aap se connect hona chahta hai.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (accept != true) {
      await Nearby().rejectConnection(id);
      return;
    }

    try {
      await Nearby().acceptConnection(
        id,
        onPayLoadRecieved: (endpointId, payload) {
          if (payload.type == PayloadType.BYTES &&
              payload.bytes != null) {
            final text = utf8.decode(
              payload.bytes!,
              allowMalformed: true,
            );

            if (mounted) {
              setState(() {
                connected[endpointId] =
                    connected[endpointId] ?? deviceName;
                messages.add(ChatMessage(text, false));
              });
            }
          }
        },
        onPayloadTransferUpdate: (endpointId, update) {},
      );

      if (mounted) {
        setState(() {
          connected[id] = deviceName;
          devices.remove(id);
        });
      }
      notify('Connection accept kar li.');
    } catch (e) {
      notify('Accept error: $e');
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    if (connected.isEmpty) {
      notify('Pehle doosre phone ko connect karo.');
      return;
    }

    try {
      final bytes = Uint8List.fromList(utf8.encode(text));

      for (final id in connected.keys.toList()) {
        await Nearby().sendBytesPayload(id, bytes);
      }

      setState(() {
        messages.add(ChatMessage(text, true));
        messageController.clear();
      });
    } catch (e) {
      notify('Message send nahi hua: $e');
    }
  }

  Future<void> stopConnections() async {
    try {
      await Nearby().stopDiscovery();
      await Nearby().stopAdvertising();
      await Nearby().stopAllEndpoints();
      if (mounted) {
        setState(() {
          connected.clear();
          devices.clear();
          busy = false;
        });
      }
      notify('Connections band kar diye.');
    } catch (e) {
      notify('Error: $e');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BlueShare',
          style: TextStyle(
            color: blue,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Stop connections',
            onPressed: stopConnections,
            icon: const Icon(Icons.link_off),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          buildChats(),
          buildStatus(),
          buildCalls(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.circle_outlined),
            selectedIcon: Icon(Icons.circle),
            label: 'Status',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Calls',
          ),
        ],
      ),
    );
  }

  Widget buildChats() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Your device name',
              prefixIcon: Icon(Icons.phone_android),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: startAdvertising,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Make discoverable'),
              ),
              FilledButton.tonalIcon(
                onPressed: startDiscovery,
                icon: const Icon(Icons.search),
                label: const Text('Find phones'),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.bluetooth_connected, color: blue),
          title: Text('Connected: ${connected.length}'),
          subtitle: Text(
            connected.values.isEmpty
                ? 'Abhi koi phone connect nahi hai'
                : connected.values.join(', '),
          ),
        ),
        if (devices.isNotEmpty)
          const ListTile(
            title: Text('Nearby devices'),
            subtitle: Text(
              'Connection request bheji ja rahi hai...',
            ),
          ),
        const Divider(),
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text('Connect karo aur apna pehla message bhejo.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Align(
                      alignment: message.mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: message.mine ? blue : panel,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(message.text),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    onSubmitted: (_) => sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Message likho...',
                      border: OutlineInputBorder(),
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
        ),
      ],
    );
  }

  Widget buildStatus() {
    return const Center(
      child: Text('Status sharing abhi implement nahi hui.'),
    );
  }

  Widget buildCalls() {
    return const Center(
      child: Text('Voice aur video calls agle phase mein.'),
    );
  }
}

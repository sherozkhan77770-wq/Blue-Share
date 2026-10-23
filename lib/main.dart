
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

const serviceId = 'com.example.blue_share';

void main() {
  runApp(const BlueShareApp());
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
        scaffoldBackgroundColor: const Color(0xFF080D18),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF168BFF),
          brightness: Brightness.dark,
        ),
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
  bool discovering = false;
  final nameController =
      TextEditingController(text: 'BlueShare User');
  final messageController = TextEditingController();

  final messages = <ChatMessage>[];
  final devices = <String, String>{};
  final connected = <String, String>{};

  String? activeDevice;

  @override
  void dispose() {
    nameController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void notify(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<bool> getPermissions() async {
    final results = await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();

    final granted = results.values.any(
      (p) => p.isGranted,
    );

    if (!granted) {
      notify('Bluetooth/Nearby permissions allow karo.');
      return false;
    }
    return true;
  }

  Future<void> findDevices() async {
    if (busy) return;
    if (!await getPermissions()) return;

    setState(() {
      busy = true;
      discovering = true;
      devices.clear();
    });

    try {
      await Nearby().startDiscovery(
        nameController.text.trim().isEmpty
            ? 'BlueShare User'
            : nameController.text.trim(),
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, foundServiceId) {
          if (!mounted || foundServiceId != serviceId) return;
          setState(() => devices[id] = name);
        },
        onEndpointLost: (id) {
          if (!mounted) return;
          setState(() => devices.remove(id));
        },
        serviceId: serviceId,
      );
      notify('Searching started. Doosre phone par bhi search/advertise karo.');
    } catch (e) {
      notify('Search error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> makeDiscoverable() async {
    if (busy) return;
    if (!await getPermissions()) return;

    setState(() => busy = true);

    try {
      await Nearby().startAdvertising(
        nameController.text.trim().isEmpty
            ? 'BlueShare User'
            : nameController.text.trim(),
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: (id, info) {
          showConnectionDialog(id, info.endpointName);
        },
        onConnectionResult: (id, status) {
          if (!mounted) return;
          setState(() {
            busy = false;
            if (status == Status.CONNECTED) {
              connected[id] = devices[id] ?? id;
              activeDevice = id;
            }
          });
          notify('Connection status: $status');
        },
        onDisconnected: (id) {
          if (!mounted) return;
          setState(() {
            connected.remove(id);
            if (activeDevice == id) activeDevice = null;
          });
          notify('Device disconnected');
        },
        serviceId: serviceId,
      );
      notify('Your phone is discoverable.');
    } catch (e) {
      notify('Advertising error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> connectDevice(String id) async {
    try {
      await Nearby().requestConnection(
        nameController.text.trim().isEmpty
            ? 'BlueShare User'
            : nameController.text.trim(),
        id,
        onConnectionInitiated: (endpointId, info) {
          showConnectionDialog(endpointId, info.endpointName);
        },
        onConnectionResult: (endpointId, status) {
          if (!mounted) return;
          setState(() {
            if (status == Status.CONNECTED) {
              connected[endpointId] =
                  devices[endpointId] ?? endpointId;
              activeDevice = endpointId;
            }
          });
          notify('Connection status: $status');
        },
        onDisconnected: (endpointId) {
          if (!mounted) return;
          setState(() {
            connected.remove(endpointId);
            if (activeDevice == endpointId) activeDevice = null;
          });
          notify('Device disconnected');
        },
      );
      notify('Connection request sent.');
    } catch (e) {
      notify('Connection error: $e');
    }
  }

  void showConnectionDialog(String id, String deviceName) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111D30),
        title: const Text('Connection request'),
        content: Text('$deviceName wants to connect.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await Nearby().rejectConnection(id);
              } catch (_) {}
            },
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
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
                      if (!mounted) return;
                      setState(() {
                        messages.add(ChatMessage(text, false));
                        activeDevice = endpointId;
                        connected[endpointId] =
                            deviceName;
                      });
                    }
                  },
                  onPayloadTransferUpdate: (endpointId, update) {
                    if (update.status == PayloadStatus.FAILURE) {
                      notify('Message send/receive failed.');
                    }
                  },
                );
                if (!mounted) return;
                setState(() {
                  connected[id] = deviceName;
                  activeDevice = id;
                });
                notify('Device connected!');
              } catch (e) {
                notify('Accept failed: $e');
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    final id = activeDevice;
    if (id == null || !connected.containsKey(id)) {
      notify('Pehle nearby device connect karo.');
      return;
    }

    try {
      await Nearby().sendBytesPayload(
        id,
        utf8.encode(text),
      );
      if (!mounted) return;
      setState(() => messages.add(ChatMessage(text, true)));
      messageController.clear();
    } catch (e) {
      notify('Message send nahi hua: $e');
    }
  }

  Future<void> stopSearch() async {
    try {
      await Nearby().stopDiscovery();
      await Nearby().stopAdvertising();
    } catch (_) {}
    if (!mounted) return;
    setState(() => discovering = false);
    notify('Search stopped.');
  }

  Widget deviceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'OFFLINE CONNECTION',
          style: TextStyle(
            color: Color(0xFF168BFF),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Your device name',
            prefixIcon: Icon(Icons.phone_android),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : makeDiscoverable,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Be visible'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: busy ? null : findDevices,
                icon: const Icon(Icons.search),
                label: const Text('Find devices'),
              ),
            ),
          ],
        ),
        if (discovering)
          TextButton(
            onPressed: stopSearch,
            child: const Text('Stop searching'),
          ),
        const SizedBox(height: 16),
        Text(
          'Connected devices (${connected.length})',
          style: const TextStyle(fontSize: 17),
        ),
        ...connected.entries.map(
          (entry) => ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF123C68),
              child: Icon(Icons.phone_android),
            ),
            title: Text(entry.value),
            subtitle: const Text('Connected offline'),
            trailing: IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {
                setState(() {
                  activeDevice = entry.key;
                  tab = 0;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nearby devices',
          style: TextStyle(fontSize: 17),
        ),
        if (devices.isEmpty)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'No devices found yet. Doosre phone par BlueShare khol kar Be visible dabao.',
              textAlign: TextAlign.center,
            ),
          ),
        ...devices.entries.map(
          (entry) => ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF123C68),
              child: Icon(Icons.devices),
            ),
            title: Text(entry.value),
            subtitle: const Text('Nearby device'),
            trailing: FilledButton(
              onPressed: () => connectDevice(entry.key),
              child: const Text('Connect'),
            ),
          ),
        ),
      ],
    );
  }

  Widget chatPage() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF101B2D),
          child: Row(
            children: [
              const Icon(Icons.bluetooth_connected,
                  color: Color(0xFF168BFF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activeDevice == null
                      ? 'No device selected'
                      : connected[activeDevice] ??
                          'Device selected',
                ),
              ),
              TextButton(
                onPressed: () => setState(() => tab = 1),
                child: const Text('Devices'),
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
                      Icon(Icons.chat_outlined,
                          size: 54, color: Color(0xFF168BFF)),
                      SizedBox(height: 12),
                      Text('Welcome to BlueShare'),
                      Text('Connect another phone to chat offline.'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    return Align(
                      alignment: m.mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        constraints:
                            const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: m.mine
                              ? const Color(0xFF075EB8)
                              : const Color(0xFF172337),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(m.text),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: const Color(0xFF172337),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Chats', 'Devices', 'Status', 'Calls'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1424),
        title: const Text(
          'BlueShare',
          style: TextStyle(
            color: Color(0xFF168BFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => tab = 1),
            icon: const Icon(Icons.devices),
            tooltip: 'Nearby devices',
          ),
        ],
      ),
      body: tab == 0
          ? chatPage()
          : tab == 1
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [deviceList()],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab == 2
                            ? Icons.circle_outlined
                            : Icons.call_outlined,
                        size: 55,
                        color: const Color(0xFF168BFF),
                      ),
                      const SizedBox(height: 12),
                      Text(titles[tab],
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 8),
                      Text(
                        tab == 2
                            ? 'Status feature is not implemented yet.'
                            : 'Voice calls feature is not implemented yet.',
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0C1424),
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
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
            icon: Icon(Icons.call_outlined),
            label: 'Calls',
          ),
        ],
      ),
    );
  }
}

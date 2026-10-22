
import 'package:flutter/material.dart';

void main() {
  runApp(const BlueShareApp());
}

const Color blue = Color(0xFF1687FF);
const Color background = Color(0xFF080D16);
const Color panel = Color(0xFF111A29);

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
  final List<String> messages = [];
  final TextEditingController messageController =
      TextEditingController();

  final List<String> tabs = [
    'Chats',
    'Status',
    'Calls',
    'Nearby',
    'Settings',
  ];

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  void addMessage() {
    final value = messageController.text.trim();
    if (value.isEmpty) return;

    setState(() {
      messages.add(value);
      messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
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
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF123D77), Color(0xFF111A29)],
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
          const SizedBox(height: 12),
          Expanded(child: buildPage()),
        ],
      ),
    );
  }

  Widget buildPage() {
    switch (selectedTab) {
      case 0:
        return buildChats();
      case 1:
        return buildSimplePage(
          Icons.circle_outlined,
          'Your status',
          'Status sharing will be added next.',
        );
      case 2:
        return buildSimplePage(
          Icons.call_outlined,
          'Recent calls',
          'Your calls will appear here.',
        );
      case 3:
        return buildNearby();
      default:
        return buildSimplePage(
          Icons.settings_outlined,
          'Settings',
          'BlueShare app settings',
        );
    }
  }

  Widget buildChats() {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? buildSimplePage(
                  Icons.chat_bubble_outline,
                  'Welcome to BlueShare',
                  'Write a message below to try the chat interface.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: blue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(messages[index]),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  onSubmitted: (_) => addMessage(),
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
                onPressed: addMessage,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildNearby() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: blue,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect nearby devices',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Real device discovery and connection '
              'will be implemented in the next step.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Nearby connection is not implemented yet.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Find devices'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSimplePage(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: blue),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

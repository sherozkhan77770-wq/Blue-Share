import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const BlueShareApp());
}

const Color blue = Color(0xFF1687FF);
const Color dark = Color(0xFF080D16);
const Color panel = Color(0xFF121B2A);

class BlueShareApp extends StatelessWidget {
  const BlueShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BlueShare',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: dark,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final String time;
  final bool mine;
  final bool attachment;

  const ChatMessage({
    required this.text,
    required this.time,
    required this.mine,
    this.attachment = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final TextEditingController _messageController =
      TextEditingController();

  final List<ChatMessage> _messages = [];
  final List<String> _contacts = [
    'My Second Phone',
    'Friends',
    'Family',
  ];

  String _selectedChat = 'My Second Phone';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _timeNow() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final suffix = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          time: _timeNow(),
          mine: true,
        ),
      );
      _messageController.clear();
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;

    setState(() {
      _messages.add(
        ChatMessage(
          text: 'Selected file: ${file.name}',
          time: _timeNow(),
          mine: true,
          attachment: true,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'File selected. Transfer to another device is not connected yet.',
        ),
      ),
    );
  }

  void _openChat(String name) {
    setState(() {
      _selectedChat = name;
      _tab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.wifi_tethering,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BlueShare',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Chat • Share • Connect',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings will be added later.'),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: blue.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.bluetooth_searching, color: blue, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby sharing',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Offline device connection is not active yet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.circle, size: 10, color: Colors.orange),
              ],
            ),
          ),
          Expanded(child: _buildCurrentPage()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel,
        indicatorColor: blue.withValues(alpha: 0.25),
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() => _tab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
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
  }  Widget _buildCurrentPage() {
    if (_tab == 1) return _buildStatusPage();
    if (_tab == 2) return _buildCallsPage();
    return _buildChatPage();
  }

  Widget _buildChatPage() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedChat,
              isExpanded: true,
              dropdownColor: panel,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: _contacts.map((name) {
                return DropdownMenuItem<String>(
                  value: name,
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 17,
                        backgroundColor: blue,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) _openChat(value);
              },
            ),
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 64,
                        color: blue.withOpacity(0.8),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Welcome to BlueShare',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your messages will appear here.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];

                    return Align(
                      alignment: message.mine
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
                          color: message.mine ? blue : panel,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.attachment)
                              const Icon(
                                Icons.attach_file,
                                color: Colors.white,
                              ),
                            Text(message.text),
                            const SizedBox(height: 5),
                            Text(
                              message.time,
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
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            color: dark,
            child: Row(
              children: [
                IconButton(
                  onPressed: _pickFile,
                  icon: const Icon(
                    Icons.attach_file,
                    color: blue,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: panel,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: blue,
                  ),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Status',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: blue, width: 2),
            ),
            child: const CircleAvatar(
              backgroundColor: panel,
              child: Icon(Icons.add, color: blue),
            ),
          ),
          title: const Text('My status'),
          subtitle: const Text('Add a photo or video later'),
          onTap: _pickFile,
        ),
        const Divider(color: Colors.white12),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Recent updates',
            style: TextStyle(color: Colors.white60),
          ),
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Text(
              'No status updates yet.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallsPage() {
  return ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      Text(
        'Calls',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      SizedBox(height: 16),
      Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            children: [
              Icon(
                Icons.call_outlined,
                size: 60,
                color: blue,
              ),
              SizedBox(height: 12),
              Text(
                'No calls yet',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'Calling feature is not connected yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  }

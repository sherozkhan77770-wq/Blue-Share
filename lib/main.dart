
import 'package:flutter/material.dart';

const Color blue = Color(0xFF1687FF);
const Color backgroundColor = Color(0xFF080B12);
const Color cardColor = Color(0xFF121722);

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
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: blue,
          secondary: blue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: cardColor,
          indicatorColor: Color(0xFF173B65),
        ),
        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          backgroundColor: blue,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const BlueShareHome(),
    );
  }
}

class BlueShareHome extends StatefulWidget {
  const BlueShareHome({super.key});

  @override
  State<BlueShareHome> createState() => _BlueShareHomeState();
}

class _BlueShareHomeState extends State<BlueShareHome> {
  int selectedIndex = 0;

  void showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is not connected yet.'),
      ),
    );
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
            onPressed: showComingSoon,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: showComingSoon,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          _buildChatsPage(),
          _buildStatusPage(),
          _buildCallsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            selectedIndex = index;
          });
        },
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
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton(
              onPressed: showComingSoon,
              child: const Icon(Icons.chat),
            )
          : null,
    );
  }

  Widget _buildChatsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text(
          'Chats',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        ChatTile(
          name: 'Ali',
          message: 'Welcome to BlueShare!',
          time: '10:30 AM',
          initials: 'A',
          unreadCount: 2,
        ),
        ChatTile(
          name: 'Ahmed',
          message: 'Hello!',
          time: 'Yesterday',
          initials: 'AH',
        ),
        ChatTile(
          name: 'Family',
          message: 'Group chat',
          time: 'Yesterday',
          initials: 'F',
          unreadCount: 1,
        ),
        ChatTile(
          name: 'Friends',
          message: 'Your conversations appear here',
          time: 'Monday',
          initials: 'FR',
        ),
      ],
    );
  }

  Widget _buildStatusPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text(
          'Status',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),
        ListTile(
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: blue,
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 30,
            ),
          ),
          title: Text('My Status'),
          subtitle: Text('Tap to add a status'),
          trailing: Icon(
            Icons.add_circle,
            color: blue,
            size: 30,
          ),
        ),
        Divider(height: 32),
        Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.circle_outlined,
                  size: 56,
                  color: blue,
                ),
                SizedBox(height: 12),
                Text(
                  'No recent updates',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'Status sharing is not connected yet.',
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
}

class ChatTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final String initials;
  final int unreadCount;

  const ChatTile({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    required this.initials,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 6,
      ),
      leading: CircleAvatar(
        radius: 27,
        backgroundColor: blue,
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white60),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 5),
            CircleAvatar(
              radius: 10,
              backgroundColor: blue,
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

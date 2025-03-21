import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.notifications, color: Colors.white),
            ),
            title: Text('Product ${index + 1} is expiring soon'),
            subtitle: const Text('Expires in 3 days'),
            trailing: const Text('2h ago'),
          );
        },
      ),
    );
  }
}
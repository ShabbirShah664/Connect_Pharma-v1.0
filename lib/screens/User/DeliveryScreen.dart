import 'package:flutter/material.dart';
import 'package:connect_pharma/screens/ChatScreen.dart';

class DeliveryScreen extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final String requestId;

  const DeliveryScreen({
    super.key, 
    required this.requestData, 
    required this.requestId
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.delivery_dining, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Delivery Requested',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'A rider will be assigned to pick up your medicine shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                     const ListTile(
                      leading: Icon(Icons.location_on),
                      title: Text('Delivery Address'),
                      subtitle: Text('Your registered home address'), 
                      // TODO: Fetch actual address
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.medication),
                      title: Text(requestData['medicineName'] ?? 'Medicine'),
                      subtitle: const Text('Package ready at pharmacy'),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: '${requestId}_rider', // Matches the ID used in RiderScreen
                      title: 'Chat with Rider',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.two_wheeler),
              label: const Text('Chat with Rider'),
              style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.orange,
                 foregroundColor: Colors.white,
                 padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: requestId,
                      title: 'Chat with Pharmacist',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('Chat with Pharmacist'),
              style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.green,
                 foregroundColor: Colors.white,
                 padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // Return to home
                Navigator.pop(context);
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

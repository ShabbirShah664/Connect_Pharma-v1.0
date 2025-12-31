import 'package:flutter/material.dart';

class SelfPickupScreen extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final String requestId;

  const SelfPickupScreen({
    super.key, 
    required this.requestData,
    required this.requestId
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Self Pickup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.store, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Ready for Pickup',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please visit the pharmacy to collect your medicine.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.store_mall_directory),
                      title: const Text('Pharmacy Location'),
                      subtitle: Text('Pharmacy ID: ${requestData['acceptedBy'] ?? 'Unknown'}'),
                      // TODO: Show actual pharmacy name and address
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Pickup Time'),
                      subtitle: const Text('Available now'),
                    ),
                  ],
                ),
              ),
            ),
             const SizedBox(height: 20),
            // Placeholder for map
            Container(
              height: 150,
              color: Colors.grey[200],
              child: const Center(child: Text('Map to Pharmacy')),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                 Navigator.pop(context);
              },
              child: const Text('I have picked it up'),
            ),
          ],
        ),
      ),
    );
  }
}

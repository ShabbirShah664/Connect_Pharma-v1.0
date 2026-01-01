import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connect_pharma/screens/ChatScreen.dart';
import 'package:maps_launcher/maps_launcher.dart';

class DeliveryScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final String requestId;

  const DeliveryScreen({
    super.key, 
    required this.requestData, 
    required this.requestId
  });

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  late LatLng _deliveryPosition;

  @override
  void initState() {
    super.initState();
    // Use the exact coordinates captured during request creation
    final lat = widget.requestData['userLat'] as double? ?? 24.8607;
    final lng = widget.requestData['userLng'] as double? ?? 67.0011;
    _deliveryPosition = LatLng(lat, lng);
  }

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
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                     ListTile(
                      leading: const Icon(Icons.location_on),
                      title: const Text('Delivery Address'),
                      subtitle: const Text('Your current location'),
                      trailing: IconButton(
                        icon: const Icon(Icons.navigation, color: Colors.blue),
                        onPressed: () {
                          MapsLauncher.launchCoordinates(
                            _deliveryPosition.latitude,
                            _deliveryPosition.longitude,
                            'Delivery Address',
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.medication),
                      title: Text(widget.requestData['medicineName'] ?? 'Medicine'),
                      subtitle: const Text('Package ready at pharmacy'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Map showing delivery location
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _deliveryPosition,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('delivery'),
                      position: _deliveryPosition,
                      infoWindow: const InfoWindow(title: 'Delivery Address'),
                    ),
                  },
                  myLocationEnabled: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: '${widget.requestId}_rider', // Matches the ID used in RiderScreen
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
                      chatId: widget.requestId,
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
            OutlinedButton(
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

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_launcher/maps_launcher.dart';

class SelfPickupScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final String requestId;

  const SelfPickupScreen({
    super.key, 
    required this.requestData, 
    required this.requestId
  });

  @override
  State<SelfPickupScreen> createState() => _SelfPickupScreenState();
}

class _SelfPickupScreenState extends State<SelfPickupScreen> {
  late LatLng _pharmacyPosition;

  @override
  void initState() {
    super.initState();
    // Use the coordinates shared by the pharmacist
    final lat = widget.requestData['pharmacyLat'] as double? ?? 24.8607;
    final lng = widget.requestData['pharmacyLng'] as double? ?? 67.0011;
    _pharmacyPosition = LatLng(lat, lng);
  }

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
                      subtitle: Text('ID: ${widget.requestData['acceptedBy'] ?? 'Unknown'}'),
                    ),
                    const Divider(),
                    ElevatedButton.icon(
                      onPressed: () {
                        MapsLauncher.launchCoordinates(
                          _pharmacyPosition.latitude,
                          _pharmacyPosition.longitude,
                          'Pharmacy Location',
                        );
                      },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Get Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Map to Pharmacy
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pharmacyPosition,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('pharmacy'),
                      position: _pharmacyPosition,
                      infoWindow: const InfoWindow(title: 'Pharmacy Location'),
                    ),
                  },
                  myLocationEnabled: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
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

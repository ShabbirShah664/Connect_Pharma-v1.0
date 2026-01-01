import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_launcher/maps_launcher.dart';

class RiderMapScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const RiderMapScreen({super.key, required this.requestData});

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen> {
  late LatLng _pharmacyPosition;
  late LatLng _deliveryPosition;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    
    // Exact locations from request data
    final pharmaLat = widget.requestData['pharmacyLat'] as double? ?? 24.8607;
    final pharmaLng = widget.requestData['pharmacyLng'] as double? ?? 67.0011;
    _pharmacyPosition = LatLng(pharmaLat, pharmaLng);

    final userLat = widget.requestData['userLat'] as double? ?? 24.8707;
    final userLng = widget.requestData['userLng'] as double? ?? 67.0111;
    _deliveryPosition = LatLng(userLat, userLng);

    _markers.add(
      Marker(
        markerId: const MarkerId('pharmacy'),
        position: _pharmacyPosition,
        infoWindow: const InfoWindow(title: 'Pharmacy (Pickup)'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('delivery'),
        position: _deliveryPosition,
        infoWindow: const InfoWindow(title: 'Delivery Address'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Route'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pharmacyPosition,
              zoom: 13,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    MapsLauncher.launchCoordinates(
                      _pharmacyPosition.latitude,
                      _pharmacyPosition.longitude,
                      'Pharmacy (Pickup)',
                    );
                  },
                  icon: const Icon(Icons.store),
                  label: const Text('Navigate to Pharmacy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    MapsLauncher.launchCoordinates(
                      _deliveryPosition.latitude,
                      _deliveryPosition.longitude,
                      'User (Delivery)',
                    );
                  },
                  icon: const Icon(Icons.person_pin_circle),
                  label: const Text('Navigate to User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

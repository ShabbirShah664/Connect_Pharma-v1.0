import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connect_pharma/screens/ChatScreen.dart';
import 'package:connect_pharma/services/request_service.dart';

class RiderMapScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const RiderMapScreen({super.key, required this.requestData});

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  late double _userLat;
  late double _userLng;
  late double _pharmacyLat;
  late double _pharmacyLng;
  String _distance = "Calculating...";
  String _pharmacyName = "Pharmacy";

  @override
  void initState() {
    super.initState();
    _userLat = (widget.requestData['userLat'] as num?)?.toDouble() ?? 0.0;
    _userLng = (widget.requestData['userLng'] as num?)?.toDouble() ?? 0.0;
    _pharmacyLat = (widget.requestData['pharmacyLat'] as num?)?.toDouble() ?? 0.0;
    _pharmacyLng = (widget.requestData['pharmacyLng'] as num?)?.toDouble() ?? 0.0;
    _fetchPharmacyLabel();
    _calculateDistance();
  }

  void _calculateDistance() {
    final distInMeters = Geolocator.distanceBetween(
      _pharmacyLat, _pharmacyLng,
      _userLat, _userLng
    );
    setState(() {
      _distance = "${(distInMeters / 1000).toStringAsFixed(1)} Km";
    });
  }

  Future<void> _fetchPharmacyLabel() async {
    final pharmacyId = widget.requestData['acceptedBy'] as String?;
    if (pharmacyId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('pharmacists').doc(pharmacyId).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _pharmacyName = data?['pharmacyName'] ?? data?['displayName'] ?? "Pharmacy";
          });
        }
      } catch (e) {
        debugPrint("Error fetching pharmacy name: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildTopBar(),
          _buildOrderDetailsCard(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_userLat == 0.0 || _pharmacyLat == 0.0) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Location data missing or invalid', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Coordinates could not be retrieved.'),
            ],
          ),
        ),
      );
    }

    _markers.clear();
    _markers.add(Marker(
      markerId: const MarkerId('pharmacy'),
      position: LatLng(_pharmacyLat, _pharmacyLng),
      infoWindow: InfoWindow(title: _pharmacyName),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ));
    _markers.add(Marker(
      markerId: const MarkerId('user'),
      position: LatLng(_userLat, _userLng),
      infoWindow: const InfoWindow(title: 'Drop-off Location'),
    ));

    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: CameraPosition(
        target: LatLng((_pharmacyLat + _userLat) / 2, (_pharmacyLng + _userLng) / 2),
        zoom: 13,
      ),
      markers: _markers,
      myLocationEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      mapType: MapType.normal,
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 50,
      left: 20,
      child: FadeInDown(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: FadeInUp(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.delivery_dining, color: Color(0xFF007BFF)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.requestData['medicineName'] ?? 'Medicine', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Order Tracker', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text(_distance, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF007BFF))),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                   Expanded(child: _locationRow(Icons.radio_button_checked, Colors.blue, _pharmacyName, 'Pickup Point')),
                   IconButton(
                    icon: const Icon(Icons.navigation_outlined, color: Color(0xFF007BFF), size: 20),
                    onPressed: () => MapsLauncher.launchCoordinates(_pharmacyLat, _pharmacyLng, _pharmacyName),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _locationRow(Icons.location_on, Colors.red, widget.requestData['userAddress'] ?? 'User Location', 'Drop-off Point')),
                  IconButton(
                    icon: const Icon(Icons.navigation_outlined, color: Color(0xFF007BFF), size: 20),
                    onPressed: () => MapsLauncher.launchCoordinates(_userLat, _userLng, 'User Location'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final status = widget.requestData['status'] ?? 'accepted';
                        String nextStatus = status == 'delivering' ? 'completed' : 'delivering';
                        try {
                           await RequestService.updateRequestStatus(widget.requestData['id'] ?? '', nextStatus);
                           if (mounted) Navigator.pop(context);
                        } catch(e) {
                           debugPrint("Status update error: $e");
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        widget.requestData['status'] == 'delivering' ? 'Mark Completed' : 'Arrived at Location', 
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      final requestId = widget.requestData['id'] ?? '';
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: '${requestId}_rider', title: 'Chat with User')));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF007BFF)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationRow(IconData icon, Color color, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }
}

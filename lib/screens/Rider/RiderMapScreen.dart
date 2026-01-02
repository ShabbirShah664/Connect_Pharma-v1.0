import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class RiderMapScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const RiderMapScreen({super.key, required this.requestData});

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen> {
  late LatLng _userPos;
  late LatLng _pharmacyPos;

  @override
  void initState() {
    super.initState();
    _userPos = LatLng(
      widget.requestData['userLat'] as double? ?? 24.8607,
      widget.requestData['userLng'] as double? ?? 67.0011,
    );
    _pharmacyPos = LatLng(
      widget.requestData['pharmacyLat'] as double? ?? 24.8600,
      widget.requestData['pharmacyLng'] as double? ?? 67.0100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _pharmacyPos, zoom: 14),
            markers: {
              Marker(markerId: const MarkerId('pharmacy'), position: _pharmacyPos, infoWindow: const InfoWindow(title: 'Pharmacy')),
              Marker(markerId: const MarkerId('user'), position: _userPos, infoWindow: const InfoWindow(title: 'User')),
            },
            myLocationEnabled: true,
            mapType: MapType.normal,
          ),
          _buildTopBar(),
          _buildOrderDetailsCard(),
        ],
      ),
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4))],
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
                        Text('Order #SDF-2342', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text('4.5 Km', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF007BFF))),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              _locationRow(Icons.radio_button_checked, Colors.blue, 'Life-Care Pharmacy', 'Pickup Point'),
              const SizedBox(height: 16),
              _locationRow(Icons.location_on, Colors.red, '2572 Westhaven Rd', 'Drop-off Point'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Arrived at Location', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
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

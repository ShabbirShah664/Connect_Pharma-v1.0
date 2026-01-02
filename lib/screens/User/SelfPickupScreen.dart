import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  late double _pharmacyLat;
  late double _pharmacyLng;

  @override
  void initState() {
    super.initState();
    _pharmacyLat = widget.requestData['pharmacyLat'] as double? ?? 24.8607;
    _pharmacyLng = widget.requestData['pharmacyLng'] as double? ?? 67.0011;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildStatusSection(),
                    const SizedBox(height: 24),
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    _buildMapSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInDown(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Text(
              'Self Pickup',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return FadeInUp(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 20)],
            ),
            child: const Icon(Icons.storefront, size: 50, color: Colors.green),
          ),
          const SizedBox(height: 16),
          Text(
            'Ready for Pickup',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'The pharmacy has prepared your medicine',
            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Column(
            children: [
              _infoRow(Icons.store_mall_directory_outlined, 'Pharmacy Point', 'Life-Care Pharmacy', () {
                MapsLauncher.launchCoordinates(_pharmacyLat, _pharmacyLng);
              }),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              _infoRow(Icons.assignment_outlined, 'Order ID', widget.requestId.substring(0, 8), null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value, VoidCallback? onNav) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (onNav != null)
          IconButton(
            icon: const Icon(Icons.directions_outlined, color: Color(0xFF4CAF50), size: 20),
            onPressed: onNav,
          ),
      ],
    );
  }

  Widget _buildMapSection() {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_pharmacyLat, _pharmacyLng),
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('pharmacy'),
                position: LatLng(_pharmacyLat, _pharmacyLng),
                infoWindow: const InfoWindow(title: 'Pharmacy Location'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
            },
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Confirm Pickup', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

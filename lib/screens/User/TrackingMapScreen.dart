import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TrackingMapScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> initialData;

  const TrackingMapScreen({
    super.key,
    required this.requestId,
    required this.initialData,
  });

  @override
  State<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends State<TrackingMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .doc(widget.requestId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data()!;
              _updateMarkers(data);

              return GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    (data['userLat'] as num?)?.toDouble() ?? 24.8607,
                    (data['userLng'] as num?)?.toDouble() ?? 67.0011,
                  ),
                  zoom: 14,
                ),
                mapType: MapType.normal,
                markers: _markers,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              );
            },
          ),
          _buildHeader(),
          _buildStatusOverlay(),
        ],
      ),
    );
  }

  void _updateMarkers(Map<String, dynamic> data) {
    _markers.clear();
    
    // User Marker
    final userLat = (data['userLat'] as num?)?.toDouble();
    final userLng = (data['userLng'] as num?)?.toDouble();
    if (userLat != null && userLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(userLat, userLng),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }

    // Pharmacy Marker
    final pLat = (data['pharmacyLat'] as num?)?.toDouble() ?? (data['lat'] as num?)?.toDouble();
    final pLng = (data['pharmacyLng'] as num?)?.toDouble() ?? (data['lng'] as num?)?.toDouble();
    if (pLat != null && pLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('pharmacy'),
        position: LatLng(pLat, pLng),
        infoWindow: const InfoWindow(title: 'Pharmacy'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Rider Marker
    if (data['status'] == 'delivering') {
      final rLat = (data['riderLat'] as num?)?.toDouble();
      final rLng = (data['riderLng'] as num?)?.toDouble();
      if (rLat != null && rLng != null) {
        _markers.add(Marker(
          markerId: const MarkerId('rider'),
          position: LatLng(rLat, rLng),
          infoWindow: const InfoWindow(title: 'Rider'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ));
      }
    }
  }

  Widget _buildNavigationCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }



  Widget _buildHeader() {
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                )
              ],
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOverlay() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: FadeInUp(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
              )
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF007BFF)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Live tracking is active. You can see the pharmacy and rider on the map.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

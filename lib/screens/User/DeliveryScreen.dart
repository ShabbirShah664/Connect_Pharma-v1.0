import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
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
    final lat = widget.requestData['userLat'] as double? ?? 24.8607;
    final lng = widget.requestData['userLng'] as double? ?? 67.0011;
    _deliveryPosition = LatLng(lat, lng);
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
              'Delivery Status',
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
              color: const Color(0xFFE3F2FD),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF007BFF).withOpacity(0.1), blurRadius: 20)],
            ),
            child: const Icon(Icons.delivery_dining, size: 50, color: Color(0xFF007BFF)),
          ),
          const SizedBox(height: 16),
          Text(
            'Order Picked Up',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Rider is on the way to your location',
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
              _infoRow(Icons.location_on, 'Delivery Address', 'Your current location', () {
                MapsLauncher.launchCoordinates(_deliveryPosition.latitude, _deliveryPosition.longitude);
              }),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              _infoRow(Icons.medication, 'Medicine', widget.requestData['medicineName'] ?? 'Panadol', null),
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
          child: Icon(icon, color: const Color(0xFF007BFF), size: 20),
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
            icon: const Icon(Icons.navigation_outlined, color: Color(0xFF007BFF), size: 20),
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
              initialCameraPosition: CameraPosition(target: _deliveryPosition, zoom: 15),
              markers: {
                Marker(markerId: const MarkerId('delivery'), position: _deliveryPosition),
              },
              zoomControlsEnabled: false,
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
            Row(
              children: [
                Expanded(child: _actionBtn('Chat with Rider', const Color(0xFF007BFF), Colors.white, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: '${widget.requestId}_rider', title: 'Chat with Rider')));
                })),
                const SizedBox(width: 12),
                Expanded(child: _actionBtn('Chat with Shop', const Color(0xFFE7F3FF), const Color(0xFF007BFF), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: widget.requestId, title: 'Chat with Pharmacist')));
                })),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Back to Home', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String text, Color bg, Color textCol, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: textCol,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

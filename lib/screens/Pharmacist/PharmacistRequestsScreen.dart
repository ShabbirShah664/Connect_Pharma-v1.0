import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_pharma/services/request_service.dart';
import 'package:connect_pharma/screens/ChatScreen.dart';
import 'package:maps_launcher/maps_launcher.dart';

class PharmacistRequestsScreen extends StatefulWidget {
  const PharmacistRequestsScreen({super.key});

  @override
  State<PharmacistRequestsScreen> createState() => _PharmacistRequestsScreenState();
}

class _PharmacistRequestsScreenState extends State<PharmacistRequestsScreen> {
  Position? _currentPosition;
  bool _loadingLocation = true;
  final String _currentPharmacistId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _loadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _loadingLocation = false);
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _loadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildCustomHeader(),
              _buildTabSelector(),
              Expanded(
                child: TabBarView(
                  children: [
                    _loadingLocation
                        ? const Center(child: CircularProgressIndicator())
                        : _buildIncomingRequests(),
                    _buildMyJobs(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return FadeInDown(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Text(
                  'CONNECT-PHARMA',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: const Color(0xFF007BFF),
        unselectedLabelColor: Colors.grey[600],
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'Incoming'),
          Tab(text: 'My Jobs'),
        ],
      ),
    );
  }

  Widget _buildIncomingRequests() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService.streamOpenBroadcastRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No active requests nearby.'));

        final filteredDocs = docs.where((doc) {
          final data = doc.data();
          final userLat = data['userLat'] as double?;
          final userLng = data['userLng'] as double?;
          final radius = (data['radius'] as num?)?.toDouble() ?? 5.0;
          if (userLat == null || userLng == null || _currentPosition == null) return true;
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude, _currentPosition!.longitude, userLat, userLng
          );
          return distance <= (radius * 1000);
        }).toList();

        if (filteredDocs.isEmpty) return const Center(child: Text('No requests within range'));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data();
            
            return FadeInUp(
              delay: Duration(milliseconds: 100 * index),
              child: _requestCard(data, doc.id),
            );
          },
        );
      },
    );
  }

  Widget _buildMyJobs() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService.streamRequestsAcceptedByPharmacist(_currentPharmacistId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No active jobs'));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return FadeInUp(
              delay: Duration(milliseconds: 100 * index),
              child: _jobCard(data, doc.id),
            );
          },
        );
      },
    );
  }

  Widget _requestCard(Map<String, dynamic> data, String requestId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['medicineName']?.toUpperCase() ?? 'MEDICINE', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _calculateDistanceString(data['userLat'], data['userLng']),
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF007BFF), fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data['userAddress'] ?? 'No address provided',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.navigation_outlined, size: 18, color: Color(0xFF007BFF)),
                onPressed: () {
                  final lat = (data['userLat'] as num?)?.toDouble();
                  final lng = (data['userLng'] as num?)?.toDouble();
                  if (lat != null && lng != null) {
                    MapsLauncher.launchCoordinates(lat, lng, 'User Location');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _acceptRequest(requestId),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Available'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _cancelRequest(requestId),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Not Available'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> data, String requestId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['medicineName']?.toUpperCase() ?? 'MEDICINE', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                Text('Status: ${data['status']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF007BFF)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: requestId, title: 'Chat with User')));
            },
          ),
        ],
      ),
    );
  }

  String _calculateDistanceString(dynamic uLat, dynamic uLng) {
    if (uLat == null || uLng == null || _currentPosition == null) return "Locating...";
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude, _currentPosition!.longitude, 
      (uLat as num).toDouble(), (uLng as num).toDouble()
    );
    if (distance < 1000) return "${distance.toInt()}m";
    return "${(distance / 1000).toStringAsFixed(1)}km";
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await RequestService.acceptRequest(requestId, _currentPharmacistId, pos.latitude, pos.longitude);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepted!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    try {
      await RequestService.cancelRequest(requestId);
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

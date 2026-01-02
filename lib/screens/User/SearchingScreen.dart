import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../services/request_service.dart';
import '../ChatScreen.dart';

class SearchingScreen extends StatefulWidget {
  final String requestId;
  final String medicineName;

  const SearchingScreen({
    super.key,
    required this.requestId,
    required this.medicineName,
  });

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _radarController.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('requests').doc(widget.requestId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final data = snapshot.data!.data();
            if (data == null) return const Center(child: Text('Request not found'));

            final status = data['status'] ?? 'open';
            final pharmacyId = (data['pharmacyId'] ?? data['acceptedBy']) as String?;
            final radius = (data['radius'] as num?)?.toDouble() ?? 5.0;

            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: status == 'open'
                      ? _buildSearchingView(radius)
                      : _buildResultsView(data, pharmacyId),
                ),
                if (status != 'open') _buildAiSuggestionsButton(),
                _buildBottomNav(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInDown(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Row(
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
      ),
    );
  }

  Widget _buildSearchingView(double radius) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeIn(
          child: Text(
            'Searching for ${widget.medicineName}',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Text(
          'Within ${radius.toInt()}km radius',
          style: GoogleFonts.inter(color: Colors.grey),
        ),
        const SizedBox(height: 50),
        AnimatedBuilder(
          animation: _radarController,
          builder: (context, child) {
            return CustomPaint(
              painter: RadarPainter(_radarController.value),
              size: const Size(200, 200),
            );
          },
        ),
        const SizedBox(height: 50),
        ElevatedButton(
          onPressed: () => RequestService.updateRequestRadius(widget.requestId, radius + 3.0),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007BFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Expand Search Area'),
        ),
        TextButton(
          onPressed: () => RequestService.cancelRequest(widget.requestId),
          child: const Text('Cancel Request', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildResultsView(Map<String, dynamic> data, String? pharmacyId) {
    if (pharmacyId == null) {
      return const Center(child: Text('No responder found yet.'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('pharmacists').doc(pharmacyId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Pharmacy information unavailable.'));
        }

        final pData = snapshot.data!.data() as Map<String, dynamic>;
        final pName = pData['displayName'] ?? pData['pharmacyName'] ?? 'Pharmacy';
        final address = pData['address'] ?? 'Nearby';

        return FadeInUp(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              Align(
                alignment: Alignment.center,
                child: Text(
                  'SearchResults',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF007BFF)),
                ),
              ),
              const SizedBox(height: 16),
              _pharmacyResponseCard(
                pName,
                address,
                'Available',
                context,
                pharmacyId,
                expanded: true,
              ),
              const SizedBox(height: 24),
              Text(
                'AI Suggestions',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _pharmacyResponseCard(
                'Lahore Care Pharmacy',
                'Limited Stock',
                'Alternative Suggested',
                context,
                null,
                isAvailable: true,
                isAi: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pharmacyResponseCard(String name, String subtitle, String status, BuildContext context, String? pharmacyId, {bool expanded = false, bool isAvailable = true, bool isAi = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAi ? Colors.blue.withOpacity(0.3) : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
       child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isAi ? Colors.blue.shade50 : const Color(0xFFE0E0E0),
                radius: 20,
                child: Icon(isAi ? Icons.psychology : Icons.person, color: isAi ? Colors.blue : Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (status.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAvailable ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.inter(
                                color: isAvailable ? Colors.green : Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _medicineItem(widget.medicineName, 'Available', context, pharmacyId),
          ]
        ],
      ),
    );
  }

  Widget _medicineItem(String name, String label, BuildContext context, String? pharmacyId, {bool isAi = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.toUpperCase(), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(isAi ? 'Alternative' : 'In Stock', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const Icon(Icons.info_outline, size: 18, color: Color(0xFF007BFF)),
          ],
        ),
        if (isAi)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Text(label, style: GoogleFonts.inter(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                    if (pharmacyId != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: widget.requestId, title: 'Chat with Pharmacist')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wait for response...')));
                    }
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text('Contact', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _initiateDelivery(),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text('Deliver', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _initiateDelivery() async {
    try {
      await RequestService.updateRequestStatus(widget.requestId, 'accepted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Confirmed! Check Tracker.')));
        Navigator.pop(context); // Go back to UserScreen
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildAiSuggestionsButton() {
    return FadeInUp(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Ask AI For Suggestions', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF007BFF),
      unselectedItemColor: Colors.grey[400],
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: 'Tracker'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
        BottomNavigationBarItem(icon: Icon(Icons.bubble_chart_outlined), label: 'AI'),
      ],
    );
  }
}

class RadarPainter extends CustomPainter {
  final double progress;
  RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    
    // Draw 3 concentric waves
    for (int i = 0; i < 3; i++) {
 waveProgress(i) {
        double p = (progress + (i * 0.33)) % 1.0;
        return p;
      }
      
      double waveP = waveProgress(i);
      final paint = Paint()
        ..color = const Color(0xFF007BFF).withOpacity(1.0 - waveP)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + (1 - waveP) * 3;

      canvas.drawCircle(center, waveP * maxRadius, paint);
      
      // Add a subtle fill for the waves
      final fillPaint = Paint()
        ..color = const Color(0xFF007BFF).withOpacity((1.0 - waveP) * 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, waveP * maxRadius, fillPaint);
    }

    // Central pulsing dot
    final dotPaint = Paint()
      ..color = const Color(0xFF007BFF)
      ..style = PaintingStyle.fill;
    
    double dotSize = 6 + (1 - (progress * 2 - 1).abs()) * 4;
    canvas.drawCircle(center, dotSize, dotPaint);
    
    // Outer glow for the central dot
    canvas.drawCircle(
      center, 
      dotSize + 4, 
      Paint()..color = const Color(0xFF007BFF).withOpacity(0.2)
    );
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) => true;
}

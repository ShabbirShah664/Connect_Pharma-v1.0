import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _go(BuildContext context, String role) {
    Navigator.pushNamed(context, '/signup', arguments: role);
  }

  Widget _roleButton(BuildContext context, String label, int index) {
    return FadeInUp(
      delay: Duration(milliseconds: 200 * index),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _go(context, label),
            icon: Icon(_getIcon(label), size: 22),
            label: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                ),
                itemBuilder: (context, index) => const Icon(Icons.map, size: 50),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  FadeInDown(child: _buildShieldLogo()),
                  const SizedBox(height: 20),
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: Column(
                      children: [
                        Text(
                          'CONNECT-PHARMA',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            color: const Color(0xFF007BFF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Find Your Medicine Fast and Easy',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeInLeft(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Login As :',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _roleButton(context, 'User', 1),
                  _roleButton(context, 'Pharmacist', 2),
                  _roleButton(context, 'Driver', 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String label) {
    switch (label) {
      case 'User': return Icons.person_outline;
      case 'Pharmacist': return Icons.local_pharmacy_outlined;
      case 'Driver': return Icons.delivery_dining_outlined;
      default: return Icons.help_outline;
    }
  }

  Widget _buildShieldLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.shield, size: 70, color: Colors.grey[200]),
            const Icon(Icons.add, size: 30, color: Color(0xFF007BFF), weight: 1000),
          ],
        ),
      ),
    );
  }
}

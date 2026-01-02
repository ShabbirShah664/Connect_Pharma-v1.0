import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';
import 'package:connect_pharma/screens/User/UserScreen.dart';
import 'package:connect_pharma/screens/Pharmacist/PharmacistScreen.dart';
import 'package:connect_pharma/screens/Rider/RiderScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _rememberMe = false;

  void _show(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _login() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) {
      _show('Please fill all fields');
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = await authService.signIn(email: _email.text.trim(), password: _pass.text);
      final role = await authService.fetchRole(cred.user!.uid);
      if (role == 'pharmacist') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PharmacistScreen()));
      } else if (role == 'rider') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiderScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserScreen()));
      }
    } catch (e) {
      _show(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                FadeInLeft(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeInDown(child: _buildShieldLogo()),
                const SizedBox(height: 30),
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
                _buildTextField('Email', _email, 'ex: jon.smith@gmail.com', false),
                const SizedBox(height: 20),
                _buildTextField('Password', _pass, '********', true),
                const SizedBox(height: 10),
                _buildRememberMe(),
                const SizedBox(height: 30),
                _buildLoginButton(),
                const SizedBox(height: 20),
                Text(
                  'or sign in with',
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _buildSocialLogins(),
                const SizedBox(height: 40),
                _buildFooter(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShieldLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.shield, size: 60, color: Colors.grey[200]),
            const Icon(Icons.add, size: 25, color: Color(0xFF007BFF), weight: 1000),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, bool obscure) {
    return FadeInUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFFBFBFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberMe() {
    return FadeInUp(
      child: Row(
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: _rememberMe,
              onChanged: (v) => setState(() => _rememberMe = v!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Remember Me',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return FadeInUp(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _login,
          icon: _loading ? Container() : const Icon(Icons.login_outlined, size: 20),
          label: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  'Log in',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007BFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLogins() {
    return FadeInUp(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _socialButton(Icons.g_mobiledata, Colors.red),
          const SizedBox(width: 20),
          _socialButton(Icons.facebook, Colors.blue[800]!),
        ],
      ),
    );
  }

  Widget _socialButton(IconData icon, Color color) {
    return Container(
      width: 100,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }

  Widget _buildFooter() {
    return FadeInUp(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Don\'t have an account? ',
            style: GoogleFonts.inter(color: Colors.grey[600]),
          ),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/roles'),
            child: Text(
              'SIGN UP',
              style: GoogleFonts.inter(
                color: const Color(0xFF007BFF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';
import 'package:connect_pharma/screens/User/UserScreen.dart';
import 'package:connect_pharma/screens/LoginScreen.dart';
import 'Pharmacist/PharmacistScreen.dart';
import 'package:connect_pharma/screens/Rider/RiderScreen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _role;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  
  bool _loading = false;
  bool _acceptTerms = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      final s = arg.trim().toLowerCase();
      if (s == 'pharmacist') {
        _role = 'pharmacist';
      } else if (s == 'driver' || s == 'rider') {
        _role = 'rider';
      } else {
        _role = 'user';
      }
    }
  }

  void _showMsg(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      _showMsg('Please accept terms & policy');
      return;
    }
    if (_passCtrl.text != _confirmPassCtrl.text) {
      _showMsg('Passwords do not match');
      return;
    }

    setState(() => _loading = true);
    try {
      final meta = {
        'contact': _contactCtrl.text,
        if (_role == 'pharmacist') 'license': _licenseCtrl.text,
        if (_role == 'pharmacist') 'address': _addressCtrl.text,
      };

      await authService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        role: _role ?? 'user',
        displayName: _nameCtrl.text.trim(),
        meta: meta,
      );

      if (_role == 'pharmacist') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PharmacistScreen()));
      } else if (_role == 'rider') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiderScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserScreen()));
      }
    } catch (e) {
      _showMsg('Sign up failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _confirmPassCtrl.dispose();
    _contactCtrl.dispose();
    _licenseCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPharmacy = _role == 'pharmacist';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Form(
              key: _formKey,
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
                  FadeInDown(
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
                        const SizedBox(height: 4),
                        Text(
                          'Find Your Medicine Fast and Easy',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isPharmacy ? 'Register Your Pharmacy' : 'Create your Account',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildTextField(isPharmacy ? 'Pharmacy Name' : 'Name', _nameCtrl, 'ex: jon smith', false),
                  const SizedBox(height: 16),
                  _buildTextField('Email', _emailCtrl, 'ex: jon.smith@gmail.com', false, keyboardType: TextInputType.emailAddress),
                  if (isPharmacy) ...[
                    const SizedBox(height: 16),
                    _buildTextField('Licence Number', _licenseCtrl, '123-456-789', false),
                  ],
                  const SizedBox(height: 16),
                  _buildTextField('Password', _passCtrl, '********', true),
                  const SizedBox(height: 16),
                  _buildTextField('Confirm password', _confirmPassCtrl, '********', true),
                  const SizedBox(height: 16),
                  _buildTextField('Contact Number', _contactCtrl, '+92 300-1234567', false, keyboardType: TextInputType.phone),
                  if (isPharmacy) ...[
                    const SizedBox(height: 16),
                    _buildTextField('Address', _addressCtrl, 'Pharmacy full address', false),
                  ],
                  const SizedBox(height: 16),
                  _buildTermsCheckbox(),
                  const SizedBox(height: 30),
                  _buildSignUpButton(),
                  const SizedBox(height: 20),
                  Text(
                    isPharmacy ? 'or sign up with' : 'or sign up with',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  _buildSocialLogins(),
                  const SizedBox(height: 30),
                  _buildFooter(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, bool obscure, {TextInputType? keyboardType}) {
    return FadeInUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFBFBFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return FadeInUp(
      child: Row(
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: _acceptTerms,
              onChanged: (v) => setState(() => _acceptTerms = v!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              children: [
                Text('I Accept the ', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                Text('terms & policy.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF007BFF), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpButton() {
    return FadeInUp(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading ? Container() : const Icon(Icons.person_add_alt_1_outlined, size: 20),
          label: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  'SIGN UP',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007BFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
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
      width: 80,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildFooter() {
    return FadeInUp(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Have an account? ',
            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
          ),
          TextButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: Text(
              'SIGN IN',
              style: GoogleFonts.inter(
                color: const Color(0xFF007BFF),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

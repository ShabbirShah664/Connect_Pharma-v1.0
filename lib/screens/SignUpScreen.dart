
import 'package:flutter/material.dart';
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
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) _role = arg;
    if (arg is String) {
      // normalize incoming role strings (e.g. "Pharmacist", "Driver", "User")
      final s = arg.trim().toLowerCase();
      if (s == 'pharmacist') {
        _role = 'pharmacist';
      } else if (s == 'driver' || s == 'rider') {
        _role = 'rider';
      } else if (s == 'user') {
        _role = 'user';
      } else {
        _role = s; // fallback
    }
    debugPrint('SignUpScreen: normalized role=$_role (from arg="$arg")');
    }
  }

  void _showMsg(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null) {
      _showMsg('Please select a role before signing up.');
      return;
    }

    setState(() => _loading = true);
    try {
      debugPrint('Signing up role=$_role email=${_emailCtrl.text}');
      final cred = await authService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        role: _role!,
        displayName: _nameCtrl.text.trim(),
      );
      debugPrint('SignUp succeeded uid=${cred.user?.uid}');

      // navigate to role-specific screen
      if (_role == 'pharmacist') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PharmacistScreen()));
      } else if (_role == 'rider') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiderScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserScreen()));
      }
    } catch (e, st) {
      debugPrint('SignUp error: $e\n$st');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = _role ?? 'No role selected';
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('Signing up as: $roleLabel', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v ?? '').contains('@') ? null : 'Enter valid email',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v ?? '').length >= 6 ? null : 'Min 6 chars',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text('Create account'),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
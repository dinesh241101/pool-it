import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import 'otp_screen.dart';
import 'profile_setup_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _dummyLogin() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.dummyLogin();
      if (!mounted) return;
      if (ok) {
        unawaited(
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => auth.currentUser?.name.isEmpty == true ? const ProfileSetupScreen() : const HomeScreen(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Dummy login failed: ${auth.error ?? 'Unknown error'}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.signInWithGoogle();
      if (!mounted) return;
      if (ok) {
        unawaited(
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => auth.currentUser?.name.isEmpty == true ? const ProfileSetupScreen() : const HomeScreen(),
            ),
          ),
        );
      } else if (auth.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error!)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().sendOtp(_phoneController.text.trim());
      if (!mounted) return;
      unawaited(
        Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(phone: _phoneController.text.trim()))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send OTP: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF43A047), Color(0xFF2E7D32), Color(0xFF1B5E20)],
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.directions_car, size: 64, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Pool-It',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Text('Smart Car Pooling', style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Welcome Back',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in with Google or continue with your phone',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _GoogleGlyph(),
                            SizedBox(width: 12),
                            Text(
                              'Continue with Google',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!FirebaseAuthService.isConfigured) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Add Firebase credentials to enable Google sign-in.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or continue with phone',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixText: '+91 ',
                        counterText: '',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: Validators.phoneNumber,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (AppConstants.dummyLoginEnabled) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _dummyLogin,
                          icon: const Icon(Icons.science_outlined, size: 20),
                          label: const Text(
                            'Dummy Login (Skip OTP)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(
                      width: double.infinity,
                      child: Text(
                        'You will receive a 6-digit OTP via WhatsApp to verify your number.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Color(0xFF4285F4), shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}

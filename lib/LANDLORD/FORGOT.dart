// FORGOT.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ⬇️ ADD THIS so we can navigate to the reset screen
import 'package:smart_finder/LANDLORD/FORGOT2.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _email = TextEditingController();
  final _sb = Supabase.instance.client;

  bool _sending = false;
  bool _canResend = true;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  static const String _redirectUri = 'smartfinder://reset';

  // ⬇️ NEW: subscription for auth state changes (passwordRecovery)
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    // 🔔 Listen for Supabase auth events WHILE we are on ForgotPassword screen
    _authSub = _sb.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('ForgotPassword auth event: $event');

      if (!mounted) return;

      if (event == AuthChangeEvent.passwordRecovery) {
        // ✅ Supabase has detected a password recovery deep link
        // The user is now authenticated via the recovery link.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ForgotPassword2()),
        );
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _resendTimer?.cancel();

    // ⬇️ NEW: cancel listener
    _authSub?.cancel();

    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  bool _looksLikeEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());

  void _startCooldown([int s = 60]) {
    setState(() {
      _canResend = false;
      _resendSeconds = s;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() {
          _canResend = true;
          _resendSeconds = 0;
        });
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  /// Call the Edge Function `reset-password`
  Future<void> _sendResetEmailViaEdge() async {
    final email = _email.text.trim();

    if (!_looksLikeEmail(email)) {
      _snack('Please enter a valid email address.');
      return;
    }

    setState(() => _sending = true);

    try {
      final resp = await _sb.functions.invoke(
        'reset-password',
        body: {'email': email, 'redirectTo': _redirectUri},
      );

      final status = resp.status;
      final data = resp.data;

      if (status == 200) {
        final message = (data is Map && data['message'] is String)
            ? data['message'] as String
            : 'If that email exists, a reset link was sent.';
        _snack(message);
        _startCooldown(60);
      } else {
        String err;
        if (data is Map && data['error'] is String) {
          err = data['error'] as String;
        } else {
          err = 'HTTP $status';
        }
        _snack('Reset failed: $err');
      }
    } catch (e) {
      _snack('Network error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003B5C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003B5C),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "FORGOT PASSWORD",
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              SizedBox(
                height: 150,
                child: Image.asset("assets/images/logo1.png"),
              ),
              const SizedBox(height: 30),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Find your account",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Enter your registered email. We'll send you a reset link.",
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        hintText: "Email Address",
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Colors.black54,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Colors.black,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: _sending
                              ? null
                              : () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _sending ? null : _sendResetEmailViaEdge,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Submit"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        "Didn’t get it? Check spam or resend.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: (!_canResend || _sending)
                            ? null
                            : _sendResetEmailViaEdge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade100,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          _canResend
                              ? "Resend Link"
                              : "Resend in $_resendSeconds s",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

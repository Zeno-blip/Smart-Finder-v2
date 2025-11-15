import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_finder/TENANT/TFORGOT2.dart';

class TenantForgotPassword extends StatefulWidget {
  const TenantForgotPassword({super.key});

  @override
  State<TenantForgotPassword> createState() => _TenantForgotPasswordState();
}

class _TenantForgotPasswordState extends State<TenantForgotPassword> {
  final TextEditingController _emailController = TextEditingController();
  final _sb = Supabase.instance.client;

  bool _sending = false;
  bool _canResend = true;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  // Same redirect you used for landlord (smartfinder://reset)
  static const String _redirectUri = 'smartfinder://reset';

  @override
  void dispose() {
    _emailController.dispose();
    _resendTimer?.cancel();
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

  /// 🔹 Call the Edge Function `reset-password` (same as landlord)
  Future<void> _sendResetEmailViaEdge() async {
    final email = _emailController.text.trim();

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
      backgroundColor: const Color(0xFF003B5C), // Dark blue background
      appBar: AppBar(
        backgroundColor: const Color(0xFF003B5C),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
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

              // Logo
              SizedBox(
                height: 150,
                child: Image.asset(
                  "assets/images/logo1.png",
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 30),

              // Form Container
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
                      "To proceed with resetting your password, please "
                      "enter your registered email address. A secure link "
                      "will be sent to verify your identity.",
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),

                    // Email field
                    TextField(
                      controller: _emailController,
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
                            elevation: 2,
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
                            elevation: 2,
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

                    // Help Text
                    Center(
                      child: Column(
                        children: const [
                          Text(
                            "Didn’t receive the email?\nCheck your spam folder or try again.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Resend email option
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
                              ? "Resend Email"
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

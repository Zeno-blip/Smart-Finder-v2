// TENANT/TVERIFICATION.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_finder/TENANT/TLOGIN.dart';

class TenantVerification extends StatefulWidget {
  final String email;
  final String userId;
  final String? fullName; // <-- OPTIONAL, fixes your error

  const TenantVerification({
    super.key,
    required this.email,
    required this.userId,
    this.fullName,
  });

  @override
  State<TenantVerification> createState() => _TenantVerificationState();
}

class _TenantVerificationState extends State<TenantVerification> {
  final supabase = Supabase.instance.client;

  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  String get _enteredCode => _controllers.map((c) => c.text.trim()).join();

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _resendCode() async {
    try {
      final res = await supabase.functions.invoke(
        'send_otp',
        body: {
          'email': widget.email,
          'user_id': widget.userId,
          'full_name': widget.fullName, // safe if null
        },
      );
      if (res.status >= 400) {
        _msg('Resend failed: ${res.data}');
        return;
      }
      _msg('A new code was sent to ${widget.email}.');
    } catch (e) {
      _msg('Resend error: $e');
    }
  }

  Future<void> _confirmCode() async {
    final code = _enteredCode;
    if (code.length != 6) {
      _msg('Please enter the 6-digit code.');
      return;
    }

    try {
      final res = await supabase.functions.invoke(
        'verify_otp',
        body: {'email': widget.email, 'code': code},
      );
      if (res.status >= 400) {
        _msg('Verification failed: ${res.data}');
        return;
      }

      _msg('Verified! You can now log in.');
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginT()),
        (_) => false,
      );
    } catch (e) {
      _msg('Error: $e');
    }
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00324E),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                "assets/images/apartment.png",
                fit: BoxFit.cover,
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 40),
                Image.asset("assets/images/logo1.png", height: 130),
                const SizedBox(height: 50),
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 80,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Verification",
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Enter the 6-digit code sent to ${widget.email}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Code inputs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 45,
                              height: 55,
                              child: TextField(
                                controller: _controllers[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  counterText: "",
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (val) {
                                  if (val.isNotEmpty && index < 5) {
                                    FocusScope.of(context).nextFocus();
                                  }
                                },
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _confirmCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00324E),
                              padding: const EdgeInsets.symmetric(
                                vertical: 18,
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Confirm",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Didn’t receive? ",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: _resendCode,
                              child: const Text(
                                "Resend code",
                                style: TextStyle(
                                  color: Colors.lightBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

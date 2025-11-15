import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenantForgotPassword2 extends StatefulWidget {
  const TenantForgotPassword2({super.key});

  @override
  State<TenantForgotPassword2> createState() => _TenantForgotPassword2State();
}

class _TenantForgotPassword2State extends State<TenantForgotPassword2> {
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final _sb = Supabase.instance.client;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _guardHasSession();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Same strength rule as landlord: at least 8 chars with a letter and a number.
  bool _strong(String p) =>
      RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(p);

  /// Make sure the app was opened via magic link / recovery
  /// and we have an authenticated session before allowing password change.
  Future<void> _guardHasSession() async {
    final session = _sb.auth.currentSession;
    final user = _sb.auth.currentUser;

    if (session == null || user == null) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      _snack('Session expired. Please request a new reset link.');
      Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  Future<void> _submit() async {
    final p1 = _newPasswordController.text.trim();
    final p2 = _confirmPasswordController.text.trim();

    if (!_strong(p1)) {
      _snack('Use at least 8 characters with letters and a number.');
      return;
    }
    if (p1 != p2) {
      _snack('Passwords do not match.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _sb.auth.updateUser(UserAttributes(password: p1));

      _snack('Password updated. Please sign in with your new password.');
      await _sb.auth.signOut();
      if (!mounted) return;
      Navigator.popUntil(context, (r) => r.isFirst);
    } on AuthException catch (e) {
      _snack('Update failed: ${e.message}');
    } catch (e) {
      _snack('Update failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _sb.auth.currentUser?.email ?? '';

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
        child: Column(
          children: [
            const SizedBox(height: 20),

            SizedBox(
              height: 150,
              child: Image.asset(
                "assets/images/logo1.png",
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 30),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Reset your password",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  if (userEmail.isNotEmpty)
                    Center(
                      child: Text(
                        userEmail,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  const Text(
                    "Please enter your new password",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: "New Password",
                      helperText: "Min 8 chars, include letters & numbers",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
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

                  const SizedBox(height: 16),

                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: "Confirm New Password",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
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
                        onPressed: _submitting
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
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
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: _submitting
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

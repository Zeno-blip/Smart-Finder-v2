// FORGOT2.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPassword2 extends StatefulWidget {
  const ForgotPassword2({super.key});

  @override
  State<ForgotPassword2> createState() => _ForgotPassword2State();
}

class _ForgotPassword2State extends State<ForgotPassword2> {
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  final _sb = Supabase.instance.client;

  bool _obscNew = true;
  bool _obscConfirm = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _guardHasSession();
  }

  @override
  void dispose() {
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Basic strength rule: at least 8 chars with a letter and a number.
  bool _strong(String p) =>
      RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(p);

  /// Make sure the app was opened via magic link / recovery
  /// and we have an authenticated session before allowing password change.
  Future<void> _guardHasSession() async {
    final session = _sb.auth.currentSession;
    final user = _sb.auth.currentUser;
    debugPrint('ForgotPassword2 session: $session, user: $user'); // ✅

    // If no session/user, bounce back gracefully.
    if (session == null || user == null) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      _snack('Session expired. Please request a new reset link.');
      Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  Future<void> _submit() async {
    final p1 = _newPw.text.trim();
    final p2 = _confirmPw.text.trim();

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
      // Update the password for the currently authenticated (magic-link) user
      await _sb.auth.updateUser(UserAttributes(password: p1));

      _snack('Password updated. Please sign in with your new password.');
      // Clear session and return to the first route (usually Login)
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
              child: Image.asset("assets/images/logo1.png"),
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
                      "Set a new password",
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
                    "You’re signed in via a secure link. Create your new password below.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newPw,
                    obscureText: _obscNew,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: "New Password",
                      helperText: "Min 8 chars, include letters & numbers",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscNew = !_obscNew),
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
                    controller: _confirmPw,
                    obscureText: _obscConfirm,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: "Confirm New Password",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscConfirm = !_obscConfirm),
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
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.white,
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

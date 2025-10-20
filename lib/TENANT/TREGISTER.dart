// lib/TENANT/tregister.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'TLOGIN.dart';
import 'TVERIFICATION.dart';

class RegisterT extends StatefulWidget {
  const RegisterT({super.key});

  @override
  State<RegisterT> createState() => _RegisterTState();
}

class _RegisterTState extends State<RegisterT> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  final _sb = Supabase.instance.client;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _register() async {
    final fullName = _fullName.text.trim();
    final email = _email.text.trim().toLowerCase();
    final phone = _phone.text.trim();
    final pass = _password.text;
    final pass2 = _confirm.text;

    if (fullName.isEmpty || email.isEmpty || pass.isEmpty) {
      _toast('Full name, email and password are required.');
      return;
    }
    if (!email.contains('@')) {
      _toast('Please enter a valid email.');
      return;
    }
    if (pass.length < 6) {
      _toast('Password must be at least 6 characters.');
      return;
    }
    if (pass != pass2) {
      _toast('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      final existingUser = await _sb
          .from('users')
          .select('id, is_verified')
          .eq('email', email)
          .maybeSingle();

      String userId;

      if (existingUser == null) {
        final signUp = await _sb.auth.signUp(
          email: email,
          password: pass,
          data: {'full_name': fullName, 'role': 'tenant'},
        );
        final authUser = signUp.user;
        if (authUser == null) {
          throw const AuthException(
            'Sign-up created but no user returned. Check auth settings.',
          );
        }
        userId = authUser.id;

        final hashed = sha256.convert(utf8.encode(pass)).toString();
        await _sb.from('users').insert({
          'id': userId,
          'full_name': fullName,
          'email': email,
          'phone': phone.isEmpty ? null : phone,
          'password': hashed,
          'role': 'tenant',
          'is_verified': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        final signIn = await _sb.auth.signInWithPassword(
          email: email,
          password: pass,
        );
        final authUser = signIn.user;
        if (authUser == null) {
          _toast(
            'Email already exists. Enter the same password used for this email.',
          );
          return;
        }
        userId = authUser.id;
      }

      try {
        await _sb.from('user_roles').insert({
          'user_id': userId,
          'role': 'tenant',
        });
      } catch (_) {}

      try {
        await _sb.from('tenant_profile').insert({
          'user_id': userId,
          'full_name': fullName,
          'phone': phone.isEmpty ? null : phone,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}

      final fnRes = await _sb.functions.invoke(
        'send_otp',
        body: {'email': email, 'user_id': userId, 'full_name': fullName},
      );

      if (fnRes.data is Map && (fnRes.data as Map)['ok'] == true) {
        _toast('Verification code sent to $email');
      } else {
        _toast(
          'Failed to send code. You can try resending from the next screen.',
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TenantVerification(
            email: email,
            userId: userId,
            fullName: fullName,
          ),
        ),
      );
    } on FunctionException catch (e) {
      // FunctionException doesn't have a `message` getter.
      // Show a useful string instead (status/details inside toString()).
      _toast('Function error: $e');
      // If you want more structure and your SDK exposes them, you can also try:
      // _toast('Function error: status=${e.status}, details=${e.details}');
    } on PostgrestException catch (e) {
      _toast('Database error: ${e.message}');
    } on AuthException catch (e) {
      _toast('Auth error: ${e.message}');
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00324E), Color(0xFF005B96)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Image.asset('assets/images/logo1.png', height: 180),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Create your account',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),
                _text(_fullName, 'Full Name', Icons.person_outline),
                const SizedBox(height: 14),
                _text(
                  _email,
                  'Email Address',
                  Icons.email_outlined,
                  inputType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _text(
                  _phone,
                  'Phone Number',
                  Icons.phone_outlined,
                  inputType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                ),
                const SizedBox(height: 14),
                _text(
                  _password,
                  'Password',
                  Icons.lock_outline,
                  obscure: _obscure1,
                  trailing: IconButton(
                    icon: Icon(
                      _obscure1 ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                const SizedBox(height: 14),
                _text(
                  _confirm,
                  'Confirm Password',
                  Icons.lock_outline,
                  obscure: _obscure2,
                  trailing: IconButton(
                    icon: Icon(
                      _obscure2 ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            'REGISTER',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginT()),
                        ),
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    Widget? trailing,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: inputType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[300],
          prefixIcon: Icon(icon),
          suffixIcon: trailing,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

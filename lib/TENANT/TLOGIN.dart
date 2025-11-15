// lib/TENANT/tlogin.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- NEW

import 'TAPARTMENT.dart';
import 'TFORGOT.dart';
import 'TREGISTER.dart';

class LoginT extends StatefulWidget {
  const LoginT({super.key});

  @override
  State<LoginT> createState() => _LoginTState();
}

class _LoginTState extends State<LoginT> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false;
  bool _loading = false;
  final _sb = Supabase.instance.client;

  // keys for SharedPreferences
  static const String _rememberKey = 'tenant_remember_me';
  static const String _emailKey = 'tenant_saved_email';

  @override
  void initState() {
    super.initState();
    _loadRememberMe(); // load saved email + checkbox
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // -------- Remember me: load saved state --------
  Future<void> _loadRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRemember = prefs.getBool(_rememberKey) ?? false;
      final savedEmail = savedRemember
          ? (prefs.getString(_emailKey) ?? '')
          : '';

      if (!mounted) return;
      setState(() {
        _remember = savedRemember;
        if (savedEmail.isNotEmpty) {
          _email.text = savedEmail;
        }
      });
    } catch (_) {
      // ignore prefs errors silently
    }
  }

  // Save or clear email based on _remember
  Future<void> _applyRememberMe(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_remember) {
        await prefs.setBool(_rememberKey, true);
        await prefs.setString(_emailKey, email);
      } else {
        await prefs.setBool(_rememberKey, false);
        await prefs.remove(_emailKey);
      }
    } catch (_) {
      // ignore prefs errors silently
    }
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _password.text;

    if (email.isEmpty || pass.isEmpty) {
      _toast('Please enter email and password.');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await _sb.auth.signInWithPassword(
        email: email,
        password: pass,
      );
      final authUser = res.user;
      if (authUser == null) throw const AuthException('Invalid credentials.');

      // Check role & verification on app users table
      final u = await _sb
          .from('users')
          .select('id, role, is_verified')
          .eq('id', authUser.id)
          .maybeSingle();

      if (u == null) {
        await _sb.auth.signOut();
        _toast('Account not found.');
        return;
      }

      if ((u['role'] as String?)?.toLowerCase() != 'tenant') {
        // They might have multiple roles recorded; prefer to check user_roles if you need.
        final hasTenant = await _sb
            .from('user_roles')
            .select('role')
            .eq('user_id', authUser.id)
            .eq('role', 'tenant')
            .maybeSingle();
        if (hasTenant == null) {
          await _sb.auth.signOut();
          _toast('This account is not a tenant.');
          return;
        }
      }

      if (u['is_verified'] != true) {
        await _sb.auth.signOut();
        _toast('Please verify your email first.');
        return;
      }

      // ✅ Remember me logic after successful login
      await _applyRememberMe(email);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TenantApartment()),
      );
    } on AuthException catch (e) {
      _toast('Login failed: ${e.message}');
    } on PostgrestException catch (e) {
      _toast('Database error: ${e.message ?? 'Unknown'}');
    } catch (e) {
      _toast('Login failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00324E), Color(0xFF005B96)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Image.asset('assets/images/logo1.png', height: 200),
                const SizedBox(height: 60),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Login to your account',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _email,
                  style: const TextStyle(color: Colors.black, height: 2),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[300],
                    prefixIcon: const Icon(Icons.email_outlined),
                    hintText: 'Email Address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black, height: 2),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[300],
                    prefixIcon: const Icon(Icons.lock_outline),
                    hintText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _remember,
                          onChanged: (v) =>
                              setState(() => _remember = v ?? false),
                        ),
                        const Text(
                          'Remember me',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TenantForgotPassword(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot Password',
                        style: TextStyle(color: Colors.lightBlueAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don’t have account? ",
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterT()),
                        );
                      },
                      child: const Text(
                        "Register",
                        style: TextStyle(color: Colors.lightBlueAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

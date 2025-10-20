// register.dart
import 'dart:async' show TimeoutException; // <-- keep this
import 'dart:convert';
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart' as geo; // alias geolocator
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // PlatformException
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_finder/LANDLORD/LOGIN.dart';
import 'package:smart_finder/LANDLORD/VERIFICATION.dart';

class RegisterL extends StatefulWidget {
  const RegisterL({super.key});

  @override
  State<RegisterL> createState() => _RegisterState();
}

class _RegisterState extends State<RegisterL> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _addressController = TextEditingController();
  final _apartmentNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedGender = 'Male';
  bool _loading = false;

  bool _locating = false; // spinner flag

  PlatformFile? _barangayClearance;
  PlatformFile? _businessPermit;
  PlatformFile? _validId1;
  PlatformFile? _validId2;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthdayController.dispose();
    _addressController.dispose();
    _apartmentNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _birthdayController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // Build a readable single-line address from a placemark
  String _formatPlacemark(geocoding.Placemark p) {
    final parts =
        <String?>[
              p.street,
              p.subLocality,
              p.locality,
              p.administrativeArea,
              p.postalCode,
              p.country,
            ]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    return parts.join(', ');
  }

  /// Try to get a position using (1) current position, (2) last known, (3) first stream event.
  Future<geo.Position?> _getBestPosition() async {
    // 1) current position with timeout
    try {
      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      ).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      // continue to fallback
    } on PlatformException catch (e) {
      // On some devices this throws "Unexpected null value". We'll fall back silently.
      debugPrint('getCurrentPosition PlatformException: ${e.message}');
    } catch (_) {
      // continue to fallback
    }

    // 2) last known
    try {
      final last = await geo.Geolocator.getLastKnownPosition();
      if (last != null) return last;
    } catch (_) {
      // continue
    }

    // 3) first fix from stream
    try {
      final stream = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
      // wait for the first event (with its own timeout)
      return await stream.first.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('getPositionStream PlatformException: ${e.message}');
      return null;
    } catch (_) {
      return null;
    }
  }

  // Use current location to fill address (with robust fallbacks)
  Future<void> _detectLocationAndFillAddress() async {
    FocusScope.of(context).unfocus();
    if (!mounted) return;
    setState(() => _locating = true);

    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _msg('Location services are disabled.');
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          _msg('Location permissions are denied.');
          return;
        }
      }
      if (permission == geo.LocationPermission.deniedForever) {
        _msg('Location permissions are permanently denied.');
        return;
      }

      final pos = await _getBestPosition();
      if (pos == null) {
        _msg('Couldn’t get a GPS fix. Try again near a window or outdoors.');
        return;
      }

      final placemarks = await geocoding.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isEmpty) {
        _msg('Unable to detect address from current location.');
        return;
      }

      final formatted = _formatPlacemark(placemarks.first);
      if (!mounted) return;
      setState(() => _addressController.text = formatted);
      _msg('Address automatically detected!');
    }
    // specific first
    on geo.PermissionDefinitionsNotFoundException {
      _msg('Missing location permission declarations in AndroidManifest.xml.');
    } on geo.LocationServiceDisabledException {
      _msg('Please enable Location Services.');
    }
    // catch any platform-level anomalies (e.g., "Unexpected null value")
    on PlatformException {
      // Don’t show the raw message; offer a helpful hint instead.
      _msg(
        'Location provider had a hiccup. Please try again in a few seconds.',
      );
    } on TimeoutException {
      _msg('Getting location timed out. Try again near a window or outdoors.');
    }
    // general last
    catch (e) {
      _msg('Could not get location.');
      debugPrint('Location error: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // --- OTP / upload / register code unchanged below ---

  Future<void> _sendOtp({
    required String email,
    required String userId,
    required String fullName,
  }) async {
    final res = await supabase.functions.invoke(
      'send_otp',
      body: {'email': email, 'user_id': userId, 'full_name': fullName},
    );
    if (res.status >= 400) {
      throw Exception("Failed to send code: ${res.data}");
    }
  }

  Future<void> _ensureLandlordRole(String userId) async {
    try {
      await supabase.from('user_roles').upsert({
        'user_id': userId,
        'role': 'landlord',
      }, onConflict: 'user_id,role');
    } catch (_) {
      try {
        await supabase.from('user_roles').insert({
          'user_id': userId,
          'role': 'landlord',
        });
      } catch (_) {}
    }
  }

  Future<void> _pickDoc(void Function(PlatformFile?) assign) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'heic', 'webp'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes == null) {
        _msg('Failed to read file bytes.');
        return;
      }
      assign(file);
      if (mounted) setState(() {});
    }
  }

  Future<void> _uploadOneDoc({
    required String userId,
    required PlatformFile file,
    required String docType,
  }) async {
    final bytes = file.bytes!;
    String clean(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');

    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/${ts}_${clean(docType)}_${clean(file.name)}';

    await supabase.storage
        .from('landlord-docs')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    await supabase.from('landlord_documents').insert({
      'user_id': userId,
      'doc_type': docType,
      'storage_path': path,
      'original_filename': file.name,
    });
  }

  Future<void> _uploadAllDocs(String userId) async {
    if (_barangayClearance != null) {
      await _uploadOneDoc(
        userId: userId,
        file: _barangayClearance!,
        docType: 'barangay_clearance',
      );
    }
    if (_businessPermit != null) {
      await _uploadOneDoc(
        userId: userId,
        file: _businessPermit!,
        docType: 'business_permit',
      );
    }
    if (_validId1 != null) {
      await _uploadOneDoc(
        userId: userId,
        file: _validId1!,
        docType: 'valid_id',
      );
    }
    if (_validId2 != null) {
      await _uploadOneDoc(
        userId: userId,
        file: _validId2!,
        docType: 'valid_id_2',
      );
    }
  }

  Future<void> _registerLandlord() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final birthday = _birthdayController.text.trim();
    final address = _addressController.text.trim();
    final aptName = _apartmentNameController.text.trim();
    final phone = _contactNumberController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      _msg('All required fields must be filled.');
      return;
    }
    if (!email.contains('@')) {
      _msg('Please enter a valid email.');
      return;
    }
    if (password != confirmPassword) {
      _msg('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);

    try {
      final existing = await supabase
          .from('users')
          .select('id, email, role')
          .eq('email', email)
          .maybeSingle();

      String userId;

      if (existing == null) {
        final res = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': '$firstName $lastName', 'role': 'landlord'},
        );

        final authUser = res.user;
        if (authUser == null) throw Exception('Sign-up failed');
        userId = authUser.id;

        final hashed = sha256.convert(utf8.encode(password)).toString();

        await supabase.from('users').upsert({
          'id': userId,
          'full_name': '$firstName $lastName',
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'phone': phone.isEmpty ? null : phone,
          'password': hashed,
          'role': 'landlord',
          'is_verified': false,
        });

        await _ensureLandlordRole(userId);

        await supabase.from('landlord_profile').upsert({
          'user_id': userId,
          'first_name': firstName,
          'last_name': lastName,
          'birthday': birthday,
          'gender': _selectedGender,
          'address': address,
          'apartment_name': aptName,
          'contact_number': phone,
        });
      } else {
        final res = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        final user = res.user;
        if (user == null) {
          _msg('Email already exists but incorrect password.');
          return;
        }
        userId = user.id;
      }

      await _uploadAllDocs(userId);
      await _sendOtp(
        email: email,
        userId: userId,
        fullName: '$firstName $lastName',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Verification(email: email, userId: userId),
        ),
      );
    } catch (e) {
      _msg('Error: $e');
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Image.asset(
                  'assets/images/logo1.png',
                  height: 230,
                ), // logo kept
                const SizedBox(height: 30),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Create your account.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  _firstNameController,
                  'First Name',
                  Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _lastNameController,
                  'Last Name',
                  Icons.person_outline,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectDate,
                        child: AbsorbPointer(
                          child: _buildTextField(
                            _birthdayController,
                            'Birthday',
                            Icons.calendar_today_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdownField(
                        'Gender',
                        _selectedGender,
                        Icons.male,
                        (v) => setState(() => _selectedGender = v ?? 'Male'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                _addressField(), // location icon kept

                const SizedBox(height: 16),

                _buildTextField(
                  _apartmentNameController,
                  'Apartment Name',
                  Icons.apartment,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _contactNumberController,
                  'Contact Number',
                  Icons.phone_outlined,
                  inputType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _emailController,
                  'Email',
                  Icons.email_outlined,
                  inputType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _passwordController,
                  'Password',
                  Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _confirmPasswordController,
                  'Confirm Password',
                  Icons.lock_outline,
                  obscureText: true,
                ),

                const SizedBox(height: 20),
                _uploadSection(),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _registerLandlord,
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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const Login()),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.lightBlueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Address field with suffix spinner/button
  Widget _addressField() {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: _addressController,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[300],
          prefixIcon: const Icon(Icons.location_on_outlined),
          hintText: 'Address',
          contentPadding: const EdgeInsets.symmetric(vertical: 18.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _locating
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Use my current location',
                  icon: const Icon(Icons.my_location),
                  onPressed: _detectLocationAndFillAddress,
                ),
        ),
      ),
    );
  }

  Widget _uploadSection() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _uploadButton(
              'Barangay Clearance',
              _barangayClearance,
              () => _pickDoc((f) => _barangayClearance = f),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _uploadButton(
              'Business Permit',
              _businessPermit,
              () => _pickDoc((f) => _businessPermit = f),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _uploadButton(
              'Valid ID',
              _validId1,
              () => _pickDoc((f) => _validId1 = f),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _uploadButton(
              'Valid ID 2',
              _validId2,
              () => _pickDoc((f) => _validId2 = f),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _uploadButton(
    String label,
    PlatformFile? picked,
    VoidCallback onPick,
  ) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPick,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.upload_file),
        label: Text(
          picked == null ? label : '$label • ${picked.name}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController c,
    String h,
    IconData i, {
    bool obscureText = false,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: c,
        obscureText: obscureText,
        keyboardType: inputType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[300],
          prefixIcon: Icon(i),
          hintText: h,
          contentPadding: const EdgeInsets.symmetric(vertical: 18.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String hint,
    String currentValue,
    IconData icon,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      height: 50,
      child: DropdownButtonFormField<String>(
        value: currentValue,
        isDense: true,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[300],
          prefixIcon: Icon(icon),
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 18.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
        items: const [
          DropdownMenuItem(value: 'Male', child: Text('Male')),
          DropdownMenuItem(value: 'Female', child: Text('Female')),
          DropdownMenuItem(value: 'Other', child: Text('Other')),
        ],
      ),
    );
  }
}

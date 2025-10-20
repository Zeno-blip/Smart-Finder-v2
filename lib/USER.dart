import 'package:flutter/material.dart';
import 'package:smart_finder/LANDLORD/REGISTER.dart';
import 'package:smart_finder/TENANT/TREGISTER.dart';

class User extends StatefulWidget {
  const User({super.key});

  @override
  State<User> createState() => _LandlordState();
}

class _LandlordState extends State<User> {
  bool _isHoveringTenant = false;
  bool _isHoveringLandlord = false;
  String? selectedRole; // Track the selected role: 'tenant' or 'landlord'

  void _onConfirm() {
    if (selectedRole == 'tenant') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RegisterT()),
      );
    } else if (selectedRole == 'landlord') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RegisterL()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04395E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Image.asset('assets/images/logo1.png', height: 230),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Welcome to Smart Finder!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Your trusted partner in finding and managing apartment rentals — helping students, professionals, and property owners connect and complete their rental journey with ease.',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Please choose how you want to use the app:',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Tenant Card
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHoveringTenant = true),
                onExit: (_) => setState(() => _isHoveringTenant = false),
                child: GestureDetector(
                  onTap: () => setState(() => selectedRole = 'tenant'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: selectedRole == 'tenant'
                          ? const Color(0xFFE0F0FF)
                          : _isHoveringTenant
                          ? const Color(0xFFE0F0FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedRole == 'tenant'
                            ? const Color(0xFF04395E)
                            : _isHoveringTenant
                            ? const Color(0xFF04395E)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: selectedRole == 'tenant'
                              ? const Color(0xFF04395E)
                              : _isHoveringTenant
                              ? const Color(0xFF04395E)
                              : Colors.black12,
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Image.asset('assets/images/TENANT.png', height: 70),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'I am a Tenant',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Tenants can browse listings, view photo tours, and contact landlords.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Landlord Card
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHoveringLandlord = true),
                onExit: (_) => setState(() => _isHoveringLandlord = false),
                child: GestureDetector(
                  onTap: () => setState(() => selectedRole = 'landlord'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: selectedRole == 'landlord'
                          ? const Color(0xFFE0F0FF)
                          : _isHoveringLandlord
                          ? const Color(0xFFE0F0FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedRole == 'landlord'
                            ? const Color(0xFF04395E)
                            : _isHoveringLandlord
                            ? const Color(0xFF04395E)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: selectedRole == 'landlord'
                              ? const Color(0xFF04395E)
                              : _isHoveringLandlord
                              ? const Color(0xFF04395E)
                              : Colors.black12,
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Image.asset('assets/images/LANDLORD.png', height: 70),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'I am a Landlord',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Landlords can post apartment rooms and manage listings responsibly.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // OLD Confirm Button (always active style)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _onConfirm,
                  child: const Text(
                    'CONFIRM',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

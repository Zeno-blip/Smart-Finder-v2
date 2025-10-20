import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class TenantEditProfile extends StatefulWidget {
  const TenantEditProfile({super.key});

  @override
  State<TenantEditProfile> createState() => _TenantEditProfileState();
}

class _TenantEditProfileState extends State<TenantEditProfile> {
  // Controllers for disabled fields
  final TextEditingController moveInController = TextEditingController(
    text: "August 21, 2025",
  );
  final TextEditingController rentController = TextEditingController(
    text: "₱3,750",
  );
  final TextEditingController roomNoController = TextEditingController(
    text: "L206",
  );
  final TextEditingController floorController = TextEditingController(
    text: "3rd Floor",
  );

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // Function to pick image
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  // Example: Show Date Picker for Move-in Date
  Future<void> _selectMoveInDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        moveInController.text = "${picked.month}/${picked.day}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "EDIT PROFILE",
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF00324E),
        elevation: 0,
      ),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Upload Photo Section (Circle)
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(color: Colors.white, width: 2),
                            image: _profileImage != null
                                ? DecorationImage(
                                    image: FileImage(_profileImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _profileImage == null
                              ? const Icon(
                                  Icons.camera_alt,
                                  size: 50,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Upload Photo",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Name
                _buildTextField(Icons.person, "Name"),
                const SizedBox(height: 15),

                // Birthday & Gender Row
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(Icons.calendar_today, "Birthday"),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(Icons.male, "Gender")),
                  ],
                ),
                const SizedBox(height: 15),

                // Address
                _buildTextField(Icons.location_on, "Address"),
                const SizedBox(height: 15),

                // Email
                _buildTextField(Icons.email, "Email"),
                const SizedBox(height: 15),

                // Contact Number
                _buildTextField(Icons.phone, "Contact Number"),
                const SizedBox(height: 15),

                // Guardian’s Contact
                _buildTextField(Icons.phone, "Guardian’s Contact No."),
                const SizedBox(height: 15),

                // Move-in & Monthly Rent (Clickable but not directly editable)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectMoveInDate,
                        child: _buildDisabledField(
                          Icons.date_range,
                          moveInController,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Monthly rent is fixed."),
                            ),
                          );
                        },
                        child: _buildDisabledField(
                          Icons.attach_money,
                          rentController,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Room No. & Room Floor (Clickable info only)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Room number is fixed."),
                            ),
                          );
                        },
                        child: _buildDisabledField(
                          Icons.meeting_room,
                          roomNoController,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Room floor is fixed."),
                            ),
                          );
                        },
                        child: _buildDisabledField(
                          Icons.layers,
                          floorController,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF04354B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Profile saved successfully!"),
                        ),
                      );
                    },
                    child: const Text(
                      "SAVE",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Editable Text Field
  Widget _buildTextField(IconData icon, String hint) {
    return GestureDetector(
      onTap: () {
        debugPrint("Clicked on $hint field");
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black87),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black54),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 12,
            ),
          ),
        ),
      ),
    );
  }

  // Disabled / Read-only Text Field with Value
  Widget _buildDisabledField(IconData icon, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        enabled: false,
        style: TextStyle(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 12,
          ),
        ),
      ),
    );
  }
}

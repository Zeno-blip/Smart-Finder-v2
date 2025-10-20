import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class TenantEditProfile extends StatefulWidget {
  // Receive current values from profile
  final String name;
  final String email;
  final String birthday;
  final String gender;
  final String address;
  final String contactNumber;
  final String guardianContact;

  final String moveIn;
  final String monthlyRent;
  final String roomNo;
  final String floorNo;

  final String? avatarPath;

  const TenantEditProfile({
    super.key,
    required this.name,
    required this.email,
    required this.birthday,
    required this.gender,
    required this.address,
    required this.contactNumber,
    required this.guardianContact,
    required this.moveIn,
    required this.monthlyRent,
    required this.roomNo,
    required this.floorNo,
    this.avatarPath,
  });

  @override
  State<TenantEditProfile> createState() => _TenantEditProfileState();
}

class _TenantEditProfileState extends State<TenantEditProfile> {
  // Editable Controllers
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController birthdayCtrl;
  late final TextEditingController genderCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController contactCtrl;
  late final TextEditingController guardianCtrl;

  // Read-only Controllers
  late final TextEditingController moveInController;
  late final TextEditingController rentController;
  late final TextEditingController roomNoController;
  late final TextEditingController floorController;

  File? _profileImage;
  String? _avatarPath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    nameCtrl = TextEditingController(text: widget.name);
    emailCtrl = TextEditingController(text: widget.email);
    birthdayCtrl = TextEditingController(text: widget.birthday);
    genderCtrl = TextEditingController(text: widget.gender);
    addressCtrl = TextEditingController(text: widget.address);
    contactCtrl = TextEditingController(text: widget.contactNumber);
    guardianCtrl = TextEditingController(text: widget.guardianContact);

    moveInController = TextEditingController(text: widget.moveIn);
    rentController = TextEditingController(text: widget.monthlyRent);
    roomNoController = TextEditingController(text: widget.roomNo);
    floorController = TextEditingController(text: widget.floorNo);

    _avatarPath = widget.avatarPath;
    if (_avatarPath != null && _avatarPath!.isNotEmpty) {
      final f = File(_avatarPath!);
      if (f.existsSync()) _profileImage = f;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    birthdayCtrl.dispose();
    genderCtrl.dispose();
    addressCtrl.dispose();
    contactCtrl.dispose();
    guardianCtrl.dispose();

    moveInController.dispose();
    rentController.dispose();
    roomNoController.dispose();
    floorController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
        _avatarPath = pickedFile.path;
      });
    }
  }

  Future<void> _selectMoveInDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        moveInController.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _saveAndClose() {
    // return a map of updated values to the profile screen
    Navigator.pop<Map<String, dynamic>>(context, {
      'name': nameCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'birthday': birthdayCtrl.text.trim(),
      'gender': genderCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
      'contactNumber': contactCtrl.text.trim(),
      'guardianContact': guardianCtrl.text.trim(),
      'moveIn': moveInController.text.trim(),
      'monthlyRent': rentController.text.trim(),
      'roomNo': roomNoController.text.trim(),
      'floorNo': floorController.text.trim(),
      'avatarPath': _avatarPath,
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _profileImage == null
        ? (widget.avatarPath == null || widget.avatarPath!.isEmpty)
              ? const Icon(Icons.camera_alt, size: 50, color: Colors.white)
              : null
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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

                // Upload Photo (Circle)
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
                                : (widget.avatarPath != null &&
                                      widget.avatarPath!.isNotEmpty)
                                ? DecorationImage(
                                    image: FileImage(File(widget.avatarPath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: avatar,
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

                _buildTextField(Icons.person, "Name", controller: nameCtrl),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        Icons.calendar_today,
                        "Birthday",
                        controller: birthdayCtrl,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        Icons.male,
                        "Gender",
                        controller: genderCtrl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                _buildTextField(
                  Icons.location_on,
                  "Address",
                  controller: addressCtrl,
                ),
                const SizedBox(height: 15),

                _buildTextField(Icons.email, "Email", controller: emailCtrl),
                const SizedBox(height: 15),

                _buildTextField(
                  Icons.phone,
                  "Contact Number",
                  controller: contactCtrl,
                ),
                const SizedBox(height: 15),

                _buildTextField(
                  Icons.phone,
                  "Guardian’s Contact No.",
                  controller: guardianCtrl,
                ),
                const SizedBox(height: 15),

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
                      child: _buildDisabledField(
                        Icons.attach_money,
                        rentController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: _buildDisabledField(
                        Icons.meeting_room,
                        roomNoController,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDisabledField(Icons.layers, floorController),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

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
                    onPressed: _saveAndClose,
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
  Widget _buildTextField(
    IconData icon,
    String hint, {
    required TextEditingController controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
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

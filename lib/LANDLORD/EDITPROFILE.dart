import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController(text: "Toto");
  final _lastNameController = TextEditingController(text: "Gandeza");
  final _birthdayController = TextEditingController(text: "1992-22-10");
  final _addressController = TextEditingController(
    text: "Gravahan Alavaran Street",
  );
  final _apartmentNameController = TextEditingController(
    text: "Smart Finder Apartment",
  );
  final _contactNumberController = TextEditingController(text: "09123456789");
  final _emailController = TextEditingController(text: "totogandeza@gmail.com");

  // 🔹 Only Guardian Contact

  String _selectedGender = 'Male';
  File? _profileImage;

  // 🔹 New uploads
  File? _businessPermit;
  File? _barangayClearance;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to pick image")));
    }
  }

  Future<void> _pickBusinessPermit() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _businessPermit = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to upload Business Permit")),
      );
    }
  }

  Future<void> _pickBarangayClearance() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _barangayClearance = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to upload Barangay Clearance")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF002D4C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'EDIT PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        centerTitle: true,
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // 🔹 Profile Picture
                  GestureDetector(
                    onTap: _pickImage,
                    child: Column(
                      children: [
                        Container(
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
                        const SizedBox(height: 10),
                        const Text(
                          "Upload Photo",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Fields...
                  _buildTextField(
                    _firstNameController,
                    "First Name",
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    _lastNameController,
                    "Last Name",
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectDate,
                          child: AbsorbPointer(
                            child: _buildTextField(
                              _birthdayController,
                              "Birthday",
                              Icons.calendar_today_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildDropdownField(
                          "Gender",
                          _selectedGender,
                          Icons.male,
                          (value) {
                            setState(() {
                              _selectedGender = value!;
                            });
                          },
                          const [
                            DropdownMenuItem(
                              value: "Male",
                              child: Text("Male"),
                            ),
                            DropdownMenuItem(
                              value: "Female",
                              child: Text("Female"),
                            ),
                            DropdownMenuItem(
                              value: "Other",
                              child: Text("Other"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  _buildTextField(
                    _addressController,
                    "Address",
                    Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    _apartmentNameController,
                    "Apartment Name",
                    Icons.apartment,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    _contactNumberController,
                    "Contact Number",
                    Icons.phone_outlined,
                    inputType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    _emailController,
                    "Email",
                    Icons.email_outlined,
                    inputType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Enter email";
                      }
                      if (!value.contains("@")) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // 🔹 New Upload Row (Business Permit + Barangay Clearance)
                  Row(
                    children: [
                      Expanded(
                        child: _buildUploadField(
                          label: "Business Permit",
                          file: _businessPermit,
                          onTap: _pickBusinessPermit,
                          icon: Icons.assignment_outlined,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildUploadField(
                          label: "Barangay Clearance",
                          file: _barangayClearance,
                          onTap: _pickBarangayClearance,
                          icon: Icons.assignment_outlined,
                        ),
                      ),
                    ],
                  ),

                  // 🔹 Guardian Contact
                  const SizedBox(height: 30),

                  // 🔹 Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF04354B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Profile saved successfully!"),
                            ),
                          );
                        }
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
      ),
    );
  }

  // 🔹 Reusable TextField
  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscureText = false,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      height: 55,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: inputType,
        inputFormatters: inputFormatters,
        validator:
            validator ??
            (value) {
              if (value == null || value.isEmpty) {
                return "Enter $hint";
              }
              return null;
            },
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[300],
          prefixIcon: Icon(icon),
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 18.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // 🔹 Reusable DropdownField
  Widget _buildDropdownField(
    String hint,
    String currentValue,
    IconData icon,
    ValueChanged<String?> onChanged,
    List<DropdownMenuItem<String>> items,
  ) {
    return SizedBox(
      height: 55,
      child: DropdownButtonFormField<String>(
        initialValue: currentValue,
        isDense: true,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[300],
          prefixIcon: Icon(icon),
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 18.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
        items: items,
      ),
    );
  }

  // 🔹 Reusable Upload Field
  Widget _buildUploadField({
    required String label,
    required File? file,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                file != null ? "Uploaded" : label,
                style: TextStyle(
                  color: file != null ? Colors.green[700] : Colors.black54,
                  fontWeight: file != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.upload_file, color: Colors.black54),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

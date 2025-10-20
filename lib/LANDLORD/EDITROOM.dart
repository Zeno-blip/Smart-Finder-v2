import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_finder/LANDLORD/EDITTOUR.dart';

class EditRoom extends StatefulWidget {
  const EditRoom({super.key});

  @override
  State<EditRoom> createState() => _EditRoomState();
}

class _EditRoomState extends State<EditRoom> {
  List<String> inclusions = []; // multiple inclusions
  List<String> preferences = []; // multiple preferences

  final List<String> inclusionOptions = ["Bed", "WiFi", "Cabinet", "Table"];
  final List<String> preferenceOptions = [
    "Male Only",
    "Female Only",
    "Mixed",
    "Couples",
    "Working Professionals",
  ];

  final List<File?> roomImages = [null, null, null]; // To store picked images

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Background Design
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00324E), Color(0xFF005B96)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          /// Main Content
          Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                centerTitle: true,
                title: const Text(
                  "EDIT ROOM INFO",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 25,
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: List.generate(3, (index) {
                          return Expanded(
                            child: InkWell(
                              onTap: () => _pickImage(index),
                              borderRadius: BorderRadius.circular(8),
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              child: Container(
                                margin: EdgeInsets.only(
                                  right: index < 2 ? 8 : 0,
                                ),
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                  image: roomImages[index] != null
                                      ? DecorationImage(
                                          image: FileImage(roomImages[index]!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: roomImages[index] == null
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.upload,
                                              size: 30,
                                              color: Colors.black,
                                            ),
                                            SizedBox(height: 5),
                                            Text(
                                              "Upload",
                                              style: TextStyle(
                                                color: Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Input Fields
                      _buildTextField(Icons.stairs, "Enter Floor Number"),
                      _buildTextField(Icons.apartment, "Enter Apartment Name"),
                      _buildTextField(Icons.location_on, "Enter Location"),
                      _buildTextField(
                        Icons.payments,
                        "Enter Monthly Payment",
                        isNumber: true,
                      ),
                      _buildTextField(
                        Icons.attach_money,
                        "Enter Advance Deposit",
                        isNumber: true,
                      ),

                      // Multi-Select Inclusion
                      _buildMultiSelect(
                        icon: Icons.chair,
                        hint: "Choose Inclusion",
                        options: inclusionOptions,
                        selectedValues: inclusions,
                        onConfirm: (selected) {
                          setState(() {
                            inclusions = selected;
                          });
                        },
                      ),

                      // Multi-Select Preference
                      _buildMultiSelect(
                        icon: Icons.sell,
                        hint: "Preference",
                        options: preferenceOptions,
                        selectedValues: preferences,
                        onConfirm: (selected) {
                          setState(() {
                            preferences = selected;
                          });
                        },
                      ),

                      // Description Box
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const TextField(
                          maxLines: 8,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Description...",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Buttons: Cancel | Hotspot | Save
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00324E),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Navigate to EditTour
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00324E),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditTour(),
                            ),
                          );
                        },
                        child: const Text(
                          "Hotspot",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Save
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00324E),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          debugPrint("Inclusions: $inclusions");
                          debugPrint("Preferences: $preferences");
                          debugPrint("Images: $roomImages");
                        },
                        child: const Text(
                          "Save",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Pick image for a specific slot
  Future<void> _pickImage(int index) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          roomImages[index] = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Widget _buildTextField(IconData icon, String hint, {bool isNumber = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.digitsOnly]
            : [],
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.black54),
          border: InputBorder.none,
          hintText: hint,
        ),
      ),
    );
  }

  Widget _buildMultiSelect({
    required IconData icon,
    required String hint,
    required List<String> options,
    required List<String> selectedValues,
    required ValueChanged<List<String>> onConfirm,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: () async {
          final result = await showDialog<List<String>>(
            context: context,
            builder: (context) {
              final tempSelected = List<String>.from(selectedValues);
              return AlertDialog(
                title: Text(hint),
                content: StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: options.map((option) {
                        return CheckboxListTile(
                          value: tempSelected.contains(option),
                          title: Text(option),
                          onChanged: (checked) {
                            setStateDialog(() {
                              if (checked == true) {
                                tempSelected.add(option);
                              } else {
                                tempSelected.remove(option);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, selectedValues),
                    child: const Text("CANCEL"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, tempSelected),
                    child: const Text("OK"),
                  ),
                ],
              );
            },
          );

          if (result != null) {
            onConfirm(result);
          }
        },
        child: Row(
          children: [
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedValues.isEmpty ? hint : selectedValues.join(", "),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

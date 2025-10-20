import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../TOUR.dart';
import 'EditRoom.dart';
import 'Addtenant.dart';

class RoomAvailable extends StatefulWidget {
  const RoomAvailable({super.key, required this.roomData});

  final Map<String, dynamic> roomData;

  @override
  State<RoomAvailable> createState() => _RoomAvailableState();
}

class _RoomAvailableState extends State<RoomAvailable> {
  int _hoveredIndex = -1;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003049),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "ROOM INFO",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _imageCarousel(context),
            const SizedBox(height: 20),
            _box1(),
            _box2(),
            _box3(),
            _box4(),
            _box5(),
            const SizedBox(height: 20),
            _roomDetailsBox(),
            const SizedBox(height: 20),
            _actionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _imageCarousel(BuildContext context) {
    final images = [
      "assets/images/roompano.png",
      "assets/images/roompano2.png",
      "assets/images/roompano3.png",
    ];

    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(images.length, (index) {
          final isHovered = index == _hoveredIndex;
          final isSelected = index == _selectedIndex;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoveredIndex = index),
                onExit: (_) => setState(() => _hoveredIndex = -1),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                      _hoveredIndex = index;
                    });

                    // ---- Extract & validate the non-null id ----
                    final dynamic rawId = widget.roomData['id'];
                    final String? id = rawId is String
                        ? rawId
                        : rawId?.toString();

                    if (id == null || id.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Missing room id.')),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Tour(
                          initialIndex: index,
                          roomId: id, // non-null now
                          titleHint:
                              widget.roomData['apartment_name'] as String?,
                          addressHint: widget.roomData['location'] as String?,
                          monthlyHint:
                              (widget.roomData['monthly_payment'] as num?)
                                  ?.toDouble(),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHovered || isSelected
                            ? const Color.fromARGB(255, 27, 70, 120)
                            : const Color.fromARGB(255, 118, 118, 118),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        images[index],
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _box1() => _infoTile(
    Icons.apartment,
    "3rd Floor",
    Icons.price_change,
    "₱3,700",
    iconSize: 28.0,
  );

  Widget _box2() => _infoTile(
    FontAwesomeIcons.doorClosed,
    "L204",
    Icons.attach_money,
    "₱3,700",
    iconSize: 28.0,
  );

  Widget _box3() => _infoTile(
    Icons.location_on,
    "Davao City, Matina Crossing \nGravahan",
    Icons.flash_on,
    "16/watts",
    iconSize: 28.0,
  );

  Widget _box4() => _infoTile(
    Icons.chair,
    "Single Bed, Table, Chair, WiFi",
    Icons.person,
    "N/A",
    iconSize: 28.0,
  );

  Widget _box5() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: const [
          Expanded(
            child: _InfoBox(
              icon: Icons.apartment,
              text: "SmartFinder Apartment",
              iconSize: 28.0,
            ),
          ),
          SizedBox(width: 10),
          Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _roomDetailsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Room Details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            "Cozy 3rd floor room at SmartFinder Apartment in Matina, Davao City. Comes with a single bed, table, chair, and Wi-Fi. All for ₱3,700/month. Ideal for students and professionals!",
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text("#NearUM", style: TextStyle(color: Colors.blue)),
              ),
              Chip(
                label: Text("#SingleBed", style: TextStyle(color: Colors.blue)),
              ),
              Chip(
                label: Text("#OwnCR", style: TextStyle(color: Colors.blue)),
              ),
              Chip(
                label: Text("#WithWiFi", style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003049),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditRoom()),
              );
            },
            child: const Text(
              "Edit Room",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003049),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Addtenant()),
              );
            },
            child: const Text(
              "Add Tenant",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoTile(
    IconData leftIcon,
    String leftText,
    IconData? rightIcon,
    String rightText, {
    double iconSize = 24.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _InfoBox(icon: leftIcon, text: leftText, iconSize: iconSize),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: (rightIcon != null && rightText.isNotEmpty)
                ? _InfoBox(icon: rightIcon, text: rightText, iconSize: iconSize)
                : const Opacity(opacity: 0, child: SizedBox(height: 80)),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.text,
    required this.iconSize,
  });

  final IconData icon;
  final String text;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black54, size: iconSize),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

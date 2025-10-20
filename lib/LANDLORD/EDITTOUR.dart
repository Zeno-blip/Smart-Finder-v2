import 'package:flutter/material.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

class EditTour extends StatefulWidget {
  const EditTour({super.key});

  @override
  State<EditTour> createState() => _EditTourState();
}

class _EditTourState extends State<EditTour> {
  // Current selected panorama
  String _selectedImage = "assets/images/roompano.png";

  // Hotspots grouped by image
  final Map<String, List<Map<String, dynamic>>> _hotspotsByImage = {};

  // Available panorama images
  final List<String> _availableImages = [
    "assets/images/roompano.png",
    "assets/images/roompano2.png",
    "assets/images/roompano3.png",
  ];

  // Keep track of which hotspot is selected (for sliders)
  int? _selectedHotspotIdx;

  @override
  Widget build(BuildContext context) {
    // Get hotspots only for the current selected image
    final List<Map<String, dynamic>> currentHotspots =
        _hotspotsByImage[_selectedImage] ?? [];

    final hasSelection =
        _selectedHotspotIdx != null &&
        _selectedHotspotIdx! >= 0 &&
        _selectedHotspotIdx! < currentHotspots.length;
    final selectedSpot = hasSelection
        ? currentHotspots[_selectedHotspotIdx!]
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF003B5C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003B5C),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "LABELED HOTSPOT",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
      ),
      body: Column(
        children: [
          // Panorama Viewer (panorama_viewer)
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    // Tap anywhere to deselect hotspot so you can pick another
                    onTap: () => setState(() => _selectedHotspotIdx = null),
                    child: PanoramaViewer(
                      child: Image.asset(_selectedImage, fit: BoxFit.cover),
                    ),
                  ),
                ),

                // Top-right: quick list of hotspots (acts like on-image markers)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: currentHotspots.isEmpty
                          ? const Text(
                              "No hotspots",
                              style: TextStyle(color: Colors.white70),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Hotspots",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ...List.generate(currentHotspots.length, (i) {
                                  final spot = currentHotspots[i];
                                  final selected = _selectedHotspotIdx == i;
                                  final label = (spot["label"] as String?)
                                      ?.trim();
                                  final title = (label?.isNotEmpty ?? false)
                                      ? label!
                                      : "Hotspot ${i + 1}";
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: InkWell(
                                      onTap: () => setState(() {
                                        _selectedHotspotIdx = i;
                                      }),
                                      onLongPress: () => _editHotspot(spot),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.place,
                                            size: 18,
                                            color: selected
                                                ? Colors.amber
                                                : Colors.white70,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            title,
                                            style: TextStyle(
                                              color: selected
                                                  ? Colors.amber
                                                  : Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),
                  ),
                ),

                // Bottom-right: Add Hotspot button
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: FloatingActionButton(
                      backgroundColor: Colors.blue,
                      onPressed: _addHotspot,
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Hotspot position controls (since panorama_viewer has no draggable hotspots)
          if (hasSelection)
            Container(
              color: const Color(0xFF6B8591),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Adjust "${(selectedSpot!["label"] as String).isNotEmpty ? selectedSpot["label"] : "Hotspot ${_selectedHotspotIdx! + 1}"}"',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _editHotspot(selectedSpot),
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          "Edit",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Longitude slider
                  Row(
                    children: [
                      const SizedBox(
                        width: 90,
                        child: Text(
                          "Longitude",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: (selectedSpot["lon"] as num).toDouble(),
                          min: -180,
                          max: 180,
                          divisions: 360,
                          label:
                              "${(selectedSpot["lon"] as num).toStringAsFixed(0)}°",
                          onChanged: (v) {
                            setState(() => selectedSpot["lon"] = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  // Latitude slider
                  Row(
                    children: [
                      const SizedBox(
                        width: 90,
                        child: Text(
                          "Latitude",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: (selectedSpot["lat"] as num).toDouble(),
                          min: -90,
                          max: 90,
                          divisions: 180,
                          label:
                              "${(selectedSpot["lat"] as num).toStringAsFixed(0)}°",
                          onChanged: (v) {
                            setState(() => selectedSpot["lat"] = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Thumbnails (with border)
          Container(
            color: const Color(0xFF6B8591),
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _availableImages.map((img) => _thumbnail(img)).toList(),
            ),
          ),

          // Save button
          Container(
            width: double.infinity,
            color: const Color(0xFF6B8591),
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003B5C),
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () {
                debugPrint("Hotspots by image: $_hotspotsByImage");
              },
              child: const Text(
                "SAVE",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Add hotspot to the current image
  void _addHotspot() {
    setState(() {
      _hotspotsByImage.putIfAbsent(_selectedImage, () => []);
      _hotspotsByImage[_selectedImage]!.add({
        "lat": 0.0,
        "lon": 0.0,
        "label": "",
        "target": null,
      });
      _selectedHotspotIdx = _hotspotsByImage[_selectedImage]!.length - 1;
    });
  }

  /// Edit hotspot (with delete button)
  void _editHotspot(Map<String, dynamic> spot) {
    final controller = TextEditingController(text: spot["label"]);
    String? selectedTarget = spot["target"];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Hotspot"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "Enter label"),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedTarget,
              decoration: const InputDecoration(
                labelText: "Navigate to",
                border: OutlineInputBorder(),
              ),
              items: _availableImages.map((img) {
                return DropdownMenuItem(
                  value: img,
                  child: Text(img.split("/").last),
                );
              }).toList(),
              onChanged: (value) {
                selectedTarget = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _hotspotsByImage[_selectedImage]?.remove(spot);
                _selectedHotspotIdx = null;
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                spot["label"] = controller.text;
                spot["target"] = selectedTarget;
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  /// Thumbnail with border
  Widget _thumbnail(String imagePath) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedImage = imagePath;
          _selectedHotspotIdx = null;
        });
      },
      child: Container(
        width: 150,
        height: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _selectedImage == imagePath
                ? Colors.blueAccent
                : const Color.fromARGB(255, 255, 255, 255),
            width: 3,
          ),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

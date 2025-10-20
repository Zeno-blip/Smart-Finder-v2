import 'package:flutter/material.dart';
import 'package:smart_finder/LANDLORD/ROOMAVAIL.dart';

class AvailableRoom extends StatefulWidget {
  const AvailableRoom({super.key});

  @override
  State<AvailableRoom> createState() => _AvailableRoomState();
}

class _AvailableRoomState extends State<AvailableRoom> {
  // All rooms are VACANT
  final List<Map<String, dynamic>> rooms = [
    {"room": "L206", "status": "VACANT"},
    {"room": "L207", "status": "VACANT"},
    {"room": "L208", "status": "VACANT"},
    {"room": "L209", "status": "VACANT"},
    {"room": "L210", "status": "VACANT"},
    {"room": "L211", "status": "VACANT"},
    {"room": "L212", "status": "VACANT"},
    {"room": "L213", "status": "VACANT"},
    {"room": "L214", "status": "VACANT"},
  ];

  int currentPage = 0;
  final int cardsPerPage = 8; // 👈 Only 8 cards per page

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int totalPages = (rooms.length / cardsPerPage).ceil();
    int startIndex = currentPage * cardsPerPage;
    int endIndex = (startIndex + cardsPerPage).clamp(0, rooms.length);

    return Scaffold(
      backgroundColor: const Color(0xFF003B5C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003B5C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "AVAILABLE ROOMS",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(12.0),
        children: [
          // 👉 Grid is wrapped so pagination comes AFTER it
          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(), // disable inner scroll
            itemCount: endIndex - startIndex,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 👈 2 cards per row
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final room = rooms[startIndex + index];

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF7B8D93),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          // Green status dot
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 62, 255, 69),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 3,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Center icon + text
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.home_rounded,
                                  size: 70,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  room['room'],
                                  style: const TextStyle(
                                    fontSize: 26,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "VACANT",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // More Info bar
                    Container(
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RoomAvailable(roomData: room),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "More Info",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 👇 Pagination shows after the last card
          const SizedBox(height: 20),
          _buildPagination(totalPages),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          IconButton(
            onPressed: currentPage > 0
                ? () {
                    setState(() {
                      currentPage--;
                      _scrollController.jumpTo(0);
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            iconSize: 30,
            color: Colors.white,
          ),
          ...List.generate(totalPages, (index) {
            bool isSelected = index == currentPage;
            return GestureDetector(
              onTap: () {
                setState(() {
                  currentPage = index;
                  _scrollController.jumpTo(0);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? const Color.fromARGB(255, 214, 214, 214)
                      : Colors.white10,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: isSelected
                      ? [
                          const BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
          IconButton(
            onPressed: currentPage < totalPages - 1
                ? () {
                    setState(() {
                      currentPage++;
                      _scrollController.jumpTo(0);
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
            iconSize: 30,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

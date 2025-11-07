import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smart_finder/LANDLORD/CHAT2.dart';
import 'package:smart_finder/LANDLORD/LSETTINGS.dart';
import 'package:smart_finder/LANDLORD/landlord_rooms_page.dart';
import 'timeline.dart';
import 'tenants.dart';
import 'totalroom.dart';
import 'availableroom.dart';
import 'apartment.dart'; // ✅ Import Apartment page

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Timeline()),
      );
    } else if (index == 2) {
      // ✅ Navigate to Apartment page instead of snackbar
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Apartment()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Tenants()),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ListChat()),
      );
    } else if (index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LandlordRoomsPage()),
      );
    } else if (index == 6) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LandlordSettings()),
      );
    } else if (index == 7) {
      // ✅ Logout
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Logged out!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A3D62),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "DASHBOARD",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 25,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ TOTAL ROOMS CARD
            _buildDashboardCard(
              "20",
              "Total Rooms",
              Icons.door_front_door,
              Colors.white,
            ),
            const SizedBox(height: 12),

            // ✅ VACANT + TENANTS
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    "20",
                    "Vacant Rooms", // ✅ Goes to AvailableRoom
                    Icons.meeting_room,
                    Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    "20",
                    "Total Tenants", // ✅ Goes to Tenants
                    Icons.group,
                    Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ✅ CHARTS
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        "Occupied and Vacant",
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: SizedBox(height: 150, child: PieChartSample()),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircleAvatar(radius: 5, backgroundColor: Colors.blue),
                          SizedBox(width: 5),
                          Text(
                            "Occupied",
                            style: TextStyle(color: Colors.white),
                          ),
                          SizedBox(width: 15),
                          CircleAvatar(radius: 5, backgroundColor: Colors.grey),
                          SizedBox(width: 5),
                          Text("Vacant", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: const [
                      Text(
                        "Tenant Growth per Month",
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: SizedBox(height: 180, child: LineChartSample()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // ✅ RECENT ACTIVITY
            const Text(
              "Recent Activity",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            _buildRecentActivity("New tenant registered today"),
            _buildRecentActivity("Room #L206 marked as occupied"),
          ],
        ),
      ),

      // ✅ Bottom Navigation Bar
      bottomNavigationBar: Container(
        color: Colors.white,
        height: 60,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(8, (index) {
              IconData icon;
              String label;
              switch (index) {
                case 0:
                  icon = Icons.dashboard;
                  label = "Dashboard";
                  break;
                case 1:
                  icon = Icons.view_timeline_outlined;
                  label = "Timeline";
                  break;
                case 2:
                  icon = Icons.apartment;
                  label = "Apartment";
                  break;
                case 3:
                  icon = Icons.group;
                  label = "Tenants";
                  break;
                case 4:
                  icon = Icons.message;
                  label = "Message";
                  break;
                case 5:
                  icon = Icons.door_front_door;
                  label = "Rooms";
                  break;
                case 6:
                  icon = Icons.settings;
                  label = "Settings";
                  break;
                case 7:
                  icon = Icons.logout;
                  label = "Logout";
                  break;
                default:
                  icon = Icons.circle;
                  label = "";
              }

              bool isSelected = _selectedIndex == index;

              return GestureDetector(
                onTap: () => _onNavTap(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3,
                        width: isSelected ? 20 : 0,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(
                        icon,
                        color: isSelected ? Colors.black : Colors.black54,
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ✅ Dashboard Cards
  Widget _buildDashboardCard(
    String number,
    String title,
    IconData icon,
    Color color,
  ) {
    return Card(
      color: const Color(0xFF1B4F72),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, color: Colors.white, size: 45),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (title == "Total Tenants") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Tenants()),
                    );
                  } else if (title == "Vacant Rooms") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AvailableRoom(),
                      ),
                    );
                  } else if (title == "Total Rooms") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TotalRoom(),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text("More Info"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Recent Activity Widget
  Widget _buildRecentActivity(String activity) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.circle, size: 10, color: Colors.lightBlue),
      title: Text(activity, style: const TextStyle(color: Colors.white)),
    );
  }
}

// ✅ Pie Chart Widget
class PieChartSample extends StatelessWidget {
  const PieChartSample({super.key});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            color: Colors.blue,
            value: 70,
            title: '',
            radius: 50,
          ),
          PieChartSectionData(
            color: Colors.grey,
            value: 30,
            title: '',
            radius: 50,
          ),
        ],
      ),
    );
  }
}

// ✅ Line Chart Widget
class LineChartSample extends StatelessWidget {
  const LineChartSample({super.key});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 5,
        maxY: 30,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value >= 5 && value <= 30) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const months = [
                  "Jan",
                  "Feb",
                  "Mar",
                  "Apr",
                  "May",
                  "Jun",
                  "Jul",
                  "Aug",
                  "Sep",
                  "Oct",
                  "Nov",
                  "Dec",
                ];
                if (value.toInt() >= 0 && value.toInt() < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      months[value.toInt()],
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 24,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: true,
          horizontalInterval: 5,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.white24, strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              FlLine(color: Colors.white24, strokeWidth: 1),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            spots: const [
              FlSpot(0, 10),
              FlSpot(1, 15),
              FlSpot(2, 12),
              FlSpot(3, 18),
              FlSpot(4, 22),
              FlSpot(5, 25),
              FlSpot(6, 28),
              FlSpot(7, 20),
              FlSpot(8, 26),
              FlSpot(9, 30),
              FlSpot(10, 24),
              FlSpot(11, 29),
            ],
            dotData: FlDotData(show: false),
            color: Colors.blue,
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

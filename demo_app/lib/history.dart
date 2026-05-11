import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

  class _HistoryPageState extends State<HistoryPage> {
    final DateTime _today = DateTime.now();
    String get _todayPath => "${_today.year}_${_today.month.toString().padLeft(2, '0')}_${_today.day.toString().padLeft(2, '0')}";
    late DatabaseReference _tempRef;
    final DatabaseReference _pumpRef = FirebaseDatabase.instance.ref('pump_history');

@override
  void initState() {
    super.initState();
    _tempRef = FirebaseDatabase.instance.ref('temp_history/$_todayPath');
  }
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 14, 42, 71),
      appBar: AppBar(
        title: Text(
          "Lịch sử hệ thống ngày ${_today.day}/${_today.month}/${_today.year}",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 14, 42, 71),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- PHẦN 1: BIỂU ĐỒ NHIỆT ĐỘ (LẤY TỪ FIREBASE) ---
            StreamBuilder(
              stream: _tempRef.limitToLast(10).onValue, // Lấy 10 bản ghi mới nhất
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  // 1. Ép kiểu dữ liệu về Map một cách an toàn
                  final rawData = snapshot.data!.snapshot.value;
                  List<Map<String, dynamic>> tempHistory = [];
      
                  if (rawData is Map) {
                    rawData.forEach((key, value) {
                      if(value is Map) {
                        tempHistory.add({
                          "time": value['time']?.toString() ?? "--:--",
                          "value": double.tryParse(value['value'].toString()) ?? 0.0,
                          "sortKey": key.toString(), // Dùng để sắp xếp
                        });
                      } 
                    });
                    // Sắp xếp theo key để đúng thứ tự thời gian
                    tempHistory.sort((a, b) => a['sortKey'].compareTo(b['sortKey']));
                  } 
                  else if (rawData is List) {
                    for (var item in rawData) {
                      if (item != null) {
                        tempHistory.add({
                          "time": item['time']?.toString() ?? "--:--",
                          "value": double.tryParse(item['value'].toString()) ?? 0.0,
                        });
                      }
                    }
                  }
                  
                  List<String> timeLabels = [];
                  List<FlSpot> allSpots = [];
    
                  for (int i = 0; i < tempHistory.length; i++) {
                    timeLabels.add(tempHistory[i]['time']);
                    allSpots.add(FlSpot(i.toDouble(), tempHistory[i]['value']));
                  }

                  final lineBarData = LineChartBarData(
                    spots: allSpots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: const Color.fromARGB(255, 245, 179, 179),
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: const Color.fromARGB(255, 240, 35, 35),
                        strokeWidth: 1,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(show: true, color: const Color.fromARGB(255, 247, 171, 94).withOpacity(0.1)),
                  );

                  return _buildChartContainer(timeLabels, allSpots, lineBarData);
                }
                return const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(
                    child: Text("Chưa có dữ liệu!", style: TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),

            // --- PHẦN 2: LỊCH SỬ MÁY BƠM (LẤY TỪ FIREBASE) ---
            StreamBuilder(
              stream: _pumpRef.limitToLast(5).onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                List<Map<String, String>> pumpHistory = [];
                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map;
                  var sortedKeys = data.keys.toList()..sort((a, b) => b.compareTo(a)); // Đảo ngược để mới nhất lên đầu
                  
                  for (var key in sortedKeys) {
                    pumpHistory.add({
                      "time": data[key]['time'].toString(),
                      "duration": data[key]['duration'].toString(),
                    });
                  }
                }
                return _buildPumpHistoryContainer(pumpHistory);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Widget giao diện biểu đồ
  Widget _buildChartContainer(List tempHistory, List<FlSpot> allSpots, LineChartBarData lineBarData) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.only(top: 10, bottom: 25, left: 35, right: 35),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 251, 248, 248),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            const Text(
              "Biểu đồ nhiệt độ & Thời gian",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
            const SizedBox(height: 50),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  showingTooltipIndicators: allSpots.asMap().entries.map((entry) {
                    return ShowingTooltipIndicators([LineBarSpot(lineBarData, 0, entry.value)]);
                  }).toList(),
                  lineTouchData: LineTouchData(
                    enabled: false,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => const Color.fromARGB(0, 1, 0, 0),
                      tooltipMargin: 2,
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        return LineTooltipItem('${spot.y}°C', const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11));
                      }).toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();

                          // chỉ hiện nếu đúng vị trí spot
                          if (index >= 0 && index < allSpots.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                tempHistory[index],
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black45,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true, 
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.18),
                        strokeWidth: 1,
                        dashArray: [6, 6],
                      );
                    },
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                  lineBarsData: [lineBarData],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget giao diện lịch sử bơm
  Widget _buildPumpHistoryContainer(List<Map<String, String>> pumpHistory) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.waves, color: Colors.blue, size: 28),
                  SizedBox(width: 10),
                  Text("Lịch sử hoạt động máy bơm", style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            if (pumpHistory.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text("Chưa có dữ liệu bơm"))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pumpHistory.length,
                separatorBuilder: (context, index) => const Divider(indent: 70),
                itemBuilder: (context, index) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.water_drop, color: Colors.blueAccent, size: 30),
                    ),
                    title: Text("Bật lúc: ${pumpHistory[index]['time']}", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    subtitle: Text("Thời gian chạy: ${pumpHistory[index]['duration']}", style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  );
                },
              ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
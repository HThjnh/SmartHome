import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:firebase_database/firebase_database.dart';
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  double temp = 0.0;
  double water_level = 0.0;
  String mode = "MANUAL";
  String PumpStatus = "OFF";
  String LedLiving = "OFF";
  String LedBed = "OFF";
  String LedKitchen = "OFF";

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  @override
  void initState() {
    super.initState();
    _listenToFirebase();
  }

  void _listenToFirebase() {
    //Lisen Temp
    _dbRef.child('roof_temp').onValue.listen((event) {
      if(event.snapshot.value != null) {
        setState(() {
          temp = double.parse(event.snapshot.value.toString());
        });
      }
    });

    //Listen water level
    _dbRef.child('water_level').onValue.listen((event) {
      if(event.snapshot.value != null) {
        setState(() {
          water_level = double.parse(event.snapshot.value.toString());
        });
      }
    });

    //Listen pump status
    _dbRef.child('roof_pump_status').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          // Firebase lưu 1/0, ta chuyển thành chuỗi ON/OFF để hiện UI
          PumpStatus = event.snapshot.value.toString() == "1" ? "ON" : "OFF";
        });
      }
    });

    //Listen system Mode
    _dbRef.child('roof_system_mode').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          mode = event.snapshot.value.toString();
        });
      }
    });

    //Listen Living LED
    _dbRef.child('led_living_status').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          LedLiving = event.snapshot.value.toString() == "1" ? "ON" : "OFF";
        });
      }
    });

    //Listen Bed LED
    _dbRef.child('led_bed_status').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          LedBed = event.snapshot.value.toString() == "1" ? "ON" : "OFF";
        });
      }
    });

    //Listen Kitchen LED
    _dbRef.child('led_kitchen_status').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          LedKitchen = event.snapshot.value.toString() == "1" ? "ON" : "OFF";
        });
      }
    });

  }
  void _toggleMode() {
    String newMode = mode == "AUTO" ? "MANUAL" : "AUTO";
    _dbRef.child('mode_control').set(newMode);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 29, 56, 93),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("SmartHome-Basys", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color.fromARGB(255, 221, 219, 219))),
              Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 231, 229, 229),
                borderRadius: BorderRadius.circular(20),
              ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatusInfo("Mode: ", mode, mode == "AUTO" ?  Color.fromARGB(255, 248, 172, 57) :  Color.fromARGB(255, 21, 152, 23)),
                    _buildStatusInfo("Bơm: ", PumpStatus, PumpStatus == "ON" ?  const Color.fromARGB(255, 3, 146, 41) : const Color.fromARGB(255, 11, 10, 10) ),
                  ],
                ),
              ),
              //1.Temp gauge (G-O-R)
              Column(
                children: [
                  const Text("Nhiệt độ ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 242, 220, 220))),
                  _buildTempGauge(temp),
                  const SizedBox(height: 10),
                ],
              ),
            //LED status, water level
            IntrinsicHeight(
              child: Row(
                children: [
                  //LED Status
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text("Hệ thống chiếu sáng: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),
                            const Divider(height: 25, thickness: 1, indent: 20, endIndent: 20),
                              _buildLedStatus("Phòng khách", LedLiving),
                              _buildLedStatus("Phòng bếp", LedKitchen),
                              _buildLedStatus("Phòng ngủ", LedBed),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  //Water level
                  Expanded(
                    flex: 1,
                    child: Card(
                      child: Padding(
                       padding: const EdgeInsets.all(10.0),
                        child: _buildWaterTank(water_level),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  //Temp Gauge
  Widget _buildTempGauge(double value) {
    Color getTempColor(double v) {
      if (v <= 25) return const Color.fromARGB(255, 47, 168, 51);        
      if (v <= 35) return Colors.orange;       
      return const Color.fromARGB(255, 255, 94, 0); 
    }
    return SizedBox(
      height: 200,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0, maximum: 50,
            axisLabelStyle:const GaugeTextStyle(
              color: Color.fromARGB(255, 178, 174, 174),           
              fontWeight: FontWeight.bold,  
              fontFamily: 'Roboto',          
            ),
            ranges: <GaugeRange>[
              GaugeRange(startValue: 0, endValue: 25, color: const Color.fromARGB(255, 31, 184, 36)),
              GaugeRange(startValue: 25, endValue: 35, color: const Color.fromARGB(255, 231, 206, 42)),
              GaugeRange(startValue: 35, endValue: 50, color: const Color.fromARGB(255, 240, 6, 6)),
            ],
            pointers: <GaugePointer>[
              NeedlePointer(value: value, needleColor: const Color.fromARGB(255, 210, 196, 196)),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Text('$value°C', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: getTempColor(value))),
                positionFactor: 0.8, angle: 90,
              )
            ],
          )
        ],
      ),
    );
  }

  //Water tank
  Widget _buildWaterTank(double level) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 120, width: 60,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: (level/100)*120,
                color: Colors.blue.withOpacity(0.6),
              ),
              Center(child: Text("${level.toInt()}%")),
            ],
          ),
        ),
        const SizedBox(height: 3),
        const Text("Mực nước ", style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatusInfo(String title, String status, Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, color: Color.fromARGB(255, 33, 33, 33), fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(status, style: TextStyle(fontSize: 22, color: textColor, fontWeight:
        FontWeight.bold)),
      ],
    );
  }

  Widget _buildLedStatus(String name, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Text(
            "$name: ", 
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
          ),
          const SizedBox(width: 8),
          Icon(
            status == "ON" 
                ? Icons.lightbulb         
                : Icons.lightbulb_outline,
            color: status == "ON" 
                ? Colors.yellow.shade700  
                : Colors.grey,            
            size: 28,                     
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

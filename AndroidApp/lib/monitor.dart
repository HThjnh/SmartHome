import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  //Device status management variable 
  bool isPumpOn = false;
  bool isAutoMode = false;
  bool isLivingLedOn = false;
  bool isKitchenLedOn = false;
  bool isBedLedOn = false;
  DateTime? _lastPumpAction;
  DateTime? _lastModeState;
  Map<String, DateTime> _lastLedAction = {};
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  @override
  void initState() {
    super.initState();
    _listenToFirebase(); //Listen to real status that device send to
  }
  void _listenToFirebase() {
    _dbRef.child('roof_pump_status').onValue.listen((event) {
      bool firebaseStatus = event.snapshot.value.toString() == "1";
      final now = DateTime.now();
      if (_lastPumpAction == null || now.difference(_lastPumpAction!).inSeconds > 5) {
        setState(() {
          isPumpOn = firebaseStatus;
        });
      }
    });

    _dbRef.child('roof_system_mode').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() => isAutoMode = event.snapshot.value.toString() == "AUTO");
      }
    });

    _dbRef.child('led_living_status').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() => isLivingLedOn = event.snapshot.value.toString() == "1");
      }
    });

    _dbRef.child('led_kitchen_status').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() => isKitchenLedOn = event.snapshot.value.toString() == "1");
      }
    });

    _dbRef.child('led_bed_status').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() => isBedLedOn = event.snapshot.value.toString() == "1");
      }
    });
  }

  // ==========================================
  // Command function to Firebase(When User press the toggle switch)
  // ==========================================
  void _togglePump(bool val) async {
  // 1. Save status that User want to orient
    final PumpState = val;
    
    setState(() {
      isPumpOn = PumpState;      //Switch UI
      _lastPumpAction = DateTime.now(); //Mark the time of the switch
    });

    try {
      // 2. Send command to Firebase
      await _dbRef.child('pump_control').set(PumpState ? 1 : 0);
    } 
    catch (e) {
      print("Lỗi gửi lệnh: $e");
      //Do not switch here
    }

    // 3. Time limit
    Future.delayed(const Duration(seconds: 5), () async {
      //Check if this is the last command(Avoid overlapping command)
      final now = DateTime.now();
      if (_lastPumpAction != null && now.difference(_lastPumpAction!).inSeconds >= 5) {
        
        //Get real status from ESP
        final snapshot = await _dbRef.child('roof_pump_status').get();
        bool actualPumpStatus = snapshot.value.toString() == "1";

        //If ESP do not reply
        if (mounted && actualPumpStatus != isPumpOn) {
          setState(() {
            isPumpOn = actualPumpStatus; //Switch to real status
          });
          _dbRef.child('pump_control').set(actualPumpStatus ? 1 : 0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Lỗi: Thiết bị không phản hổi!"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    });
  }

  void _toggleMode(bool val) async {
    final ModeState = val;
    setState(() {
      isAutoMode = ModeState;
      _lastModeState = DateTime.now();
    });
    
    try {
      await _dbRef.child('mode_control').set(ModeState ? "AUTO" : "MANUAL");
    }
    catch(e) {
      print("Lỗi gửi lệnh: $e");
    }
    Future.delayed(const Duration(seconds: 5), () async {
      //Check if this is the last command(Avoid overlapping command)
      final now = DateTime.now();
      if (_lastModeState != null && now.difference(_lastModeState!).inSeconds >= 5) {
        
        //Get real status from ESP
        final snapshot = await _dbRef.child('roof_system_mode').get();
        bool actualModeStatus = snapshot.value.toString() == "AUTO";

        //If ESP do not reply
        if (mounted && actualModeStatus != isAutoMode) {
          setState(() {
            isAutoMode = actualModeStatus; //Switch to real status
          });
          _dbRef.child('mode_control').set(actualModeStatus ? "AUTO" : "MANUAL");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Lỗi: Thiết bị không phản hồi!"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    });
  }

  void _toggleLed(String room, bool val) async {
    setState(() {
      if (room == 'living') isLivingLedOn = val;
      else if (room == 'kitchen') isKitchenLedOn = val;
      else if (room == 'bed') isBedLedOn = val;
      _lastLedAction[room] = DateTime.now();
    });
    try {
      await _dbRef.child('led_${room}_control').set(val ? 1 : 0);
    }
    catch(e) {
      print("Lỗi gửi lệnh LED: $e");
    }
    Future.delayed(const Duration(seconds: 5), () async {
      final now = DateTime.now();
      final lastAction = _lastLedAction[room];

      if (lastAction != null && now.difference(lastAction).inSeconds >= 5) {
        final snapshot = await _dbRef.child('led_${room}_status').get();
        bool actualLedStatus = snapshot.value.toString() == "1";
        bool currentUiState = false;
        if (room == 'living') currentUiState = isLivingLedOn;
        else if (room == 'kitchen') currentUiState = isKitchenLedOn;
        else if (room == 'bed') currentUiState = isBedLedOn;
        if (mounted && actualLedStatus != currentUiState) {
          setState(() {
            //Switch UI of error room
            if (room == 'living') isLivingLedOn = actualLedStatus;
            else if (room == 'kitchen') isKitchenLedOn = actualLedStatus;
            else if (room == 'bed') isBedLedOn = actualLedStatus;
          });
          _dbRef.child('led_${room}_control').set(actualLedStatus ? 1 : 0);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Lỗi: Thiết bị không phản hồi!"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 14, 42, 71),
      appBar: AppBar(
        title: const Text("Điều khiển",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            //Pump control unit
            _buildControlGroup(
              title: "Hệ thống bơm",
              children: [
                _buildControlItem(
                  label: "Bật/Tắt bơm",
                  icon: Icons.settings_input_component,
                  iconColor: Colors.blue,
                  value: isPumpOn,
                  onChanged: (val) => _togglePump(val),
                ),
                const Divider(),
                _buildControlItem(
                  label: "Auto mode",
                  icon: Icons.settings,
                  iconColor: Colors.orange,
                  value: isAutoMode,
                  onChanged: (val) => _toggleMode(val),
                ),
              ],
            ),
            const SizedBox(height: 20),

            //LED control unit
            _buildControlGroup(
              title: "Hệ thống LED",
              children: [
                _buildControlItem(
                  label: "Phòng khách",
                  icon: Icons.chair,
                  iconColor: Colors.blueAccent,
                  value: isLivingLedOn,
                  showBulb: true,
                  onChanged: (val) => _toggleLed('living', val),
                ),
                const Divider(),
                _buildControlItem(
                  label: "Phòng ngủ",
                  icon: Icons.bed,
                  iconColor: Colors.purple,
                  value: isBedLedOn,
                  showBulb: true,
                  onChanged: (val) => _toggleLed('bed', val),
                ),
                const Divider(),
                _buildControlItem(
                  label: "Phòng bếp",
                  icon: Icons.restaurant,
                  iconColor: Colors.green,
                  value: isKitchenLedOn,
                  showBulb: true,
                  onChanged: (val) => _toggleLed('kitchen', val),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlGroup(
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 15, bottom: 10),
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildControlItem({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showBulb = false,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.green,
      activeTrackColor: Colors.green.withValues(alpha: 0.5),
      secondary: Container(
        padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 28),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w500)
              )
          ),
          if (showBulb)
            Icon(
              Icons.lightbulb,
              color: value ? Colors.orange : Colors.grey.shade400,
              size: 24,
            ),
        ],
      ),
    );
  }
}
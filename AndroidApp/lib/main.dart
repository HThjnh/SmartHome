import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_database/firebase_database.dart';
import 'taskbar.dart';
import 'dashboard.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCf6SJwk7e5PovjRGCrnCLvjO69eDg0TqU",
        appId: "1:139773058447:android:6fb2c78ea5b2bcd5253ffa",
        messagingSenderId: "139773058447",
        projectId: "ce232-smarthome",
        databaseURL: "https://ce232-smarthome-default-rtdb.asia-southeast1.firebasedatabase.app",
        storageBucket: "ce232-smarthome.firebasestorage.app",
      ),
    );
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartHome',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const TaskbarScreen(),
    );
  }
}





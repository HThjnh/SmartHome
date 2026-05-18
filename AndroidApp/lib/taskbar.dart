import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'monitor.dart';
import 'history.dart';

class TaskbarScreen extends StatefulWidget {
  const TaskbarScreen({super.key});

  @override
  State<TaskbarScreen> createState() => _TaskbarScreenState();
}

class _TaskbarScreenState extends State<TaskbarScreen> {
  int _currentIndex = 0;

  
  final List<Widget> _pages = [
    DashboardPage(),
    MonitorPage(),
    HistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_remote_outlined),
            activeIcon: Icon(Icons.settings_remote),
            label: 'Điều khiển',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Lịch sử',
          ),
        ],
      ),
    );
  }
}
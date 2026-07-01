import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class MainHub extends StatefulWidget {
  const MainHub({Key? key}) : super(key: key);

  @override
  State<MainHub> createState() => _MainHubState();
}

class _MainHubState extends State<MainHub> {
  int _currentIndex = 0;

  // Daftar halaman yang mau ditampilkan
  final List<Widget> _pages = [
    const DashboardIrigasi(), // Halaman ke-1
    const HistoryIrigasi(), // Halaman ke-2
    const SettingsPage(), // Halaman ke-3 (Pengaturan)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], // Menampilkan halaman aktif
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Pindah halaman pas menu diklik
          });
        },
        selectedItemColor: Colors.teal,
        type: BottomNavigationBarType.fixed, // Tetap stabil saat ada 3+ items
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

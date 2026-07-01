import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'main_hub.dart';
import 'mqtt_manager.dart';
import 'logo_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // 🚀 UNTUK FORMAT TANGGAL DAN JAM
import 'firebase_options.dart';

// Global state/notifiers for app settings
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> userNameNotifier = ValueNotifier("Mifta");
final ValueNotifier<bool> notificationNotifier = ValueNotifier(true);
final ValueNotifier<String> mqttBrokerNotifier = ValueNotifier("broker.hivemq.com");
final ValueNotifier<int> mqttPortNotifier = ValueNotifier(1883);

Future<void> initializeApp() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase berhasil diinisialisasi');
  } catch (e) {
    print('❌ Firebase Error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentThemeMode, __) {
        return MaterialApp(
          title: 'AgroFlow',
          debugShowCheckedModeBanner: false,
          themeMode: currentThemeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF00FF87),
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            cardColor: Colors.white,
            fontFamily: 'Sans-Serif',
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF00FF87),
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF090A0F),
            cardColor: const Color(0xFF131520),
            fontFamily: 'Sans-Serif',
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/dashboard_irigasi': (context) => const DashboardIrigasi(),
            '/main_hub': (context) => const MainHub(),
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main_hub');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF090A0F), // Deep Space Navy
              Color(0xFF131520), // Dark Navy Card
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AgroFlowLogo(size: 100, showShadow: true),
              const SizedBox(height: 24),
              const Text(
                'AgroFlow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Smart Irrigation System',
                style: TextStyle(
                  color: Color(0xFF00FF87), // Neon Green
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF87)),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String suhu = "--";
  String kelembapanUdara = "--";
  String kelembapanTanah = "--";
  String statusKoneksi = "Menghubungkan...";
  String statusPompa = "MATI";
  bool isSensorError = false;
  bool _isRefreshing = false;

  final MqttManager mqttHandler = MqttManager();

  void simpanKeFirestore(String topikAsli, String nilaiPayload) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    String namaSensor = topikAsli.replaceAll('irigasi/', '');

    firestore
        .collection('history_agroflow')
        .add({
          'sensor_type': namaSensor,
          'value': double.tryParse(nilaiPayload) ?? nilaiPayload,
          'timestamp': FieldValue.serverTimestamp(),
          'waktu_lokal': DateTime.now().toString(),
        })
        .then((value) {
          print('✅ [Firebase] Berhasil mencatat riwayat data $namaSensor!');
        })
        .catchError((error) {
          print('❌ [Firebase] Gagal mencatat ke cloud: $error');
        });
  }

  void _connectMQTT() {
    setState(() {
      statusKoneksi = "Menghubungkan...";
    });
    mqttHandler.initializeMQTT(
      onConnected: () {
        if (mounted) {
          setState(() {
            statusKoneksi = "Terhubung";
          });
        }
        mqttHandler.subscribeToTopic('irigasi/suhu');
        mqttHandler.subscribeToTopic('irigasi/kelembapan_udara');
        mqttHandler.subscribeToTopic('irigasi/kelembapan_tanah');
        mqttHandler.subscribeToTopic('irigasi/pompa_kontrol');
        mqttHandler.subscribeToTopic('irigasi/status_pompa');
        mqttHandler.subscribeToTopic('irigasi/peringatan');
      },
      onMessageReceived: (topic, message) {
        simpanKeFirestore(topic, message);
        if (mounted) {
          setState(() {
            if (topic == 'irigasi/suhu') {
              suhu = message;
            } else if (topic == 'irigasi/kelembapan_udara') {
              kelembapanUdara = message;
            } else if (topic == 'irigasi/kelembapan_tanah') {
              kelembapanTanah = message;
            } else if (topic == 'irigasi/status_pompa' ||
                topic == 'irigasi/pompa_kontrol') {
              statusPompa = (message == "1") ? "NYALA" : "MATI";
            } else if (topic == 'irigasi/peringatan' && message == "BAHAYA") {
              _showEmergencyDialog();
            }
          });
        }
      },
    );
  }

  Future<void> _onPullToRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      suhu = "--";
      kelembapanUdara = "--";
      kelembapanTanah = "--";
      statusKoneksi = "Menghubungkan...";
    });

    // Coba putuskan koneksi lama (jika ada) lalu sambungkan kembali
    try {
      mqttHandler.client.disconnect();
    } catch (_) {}

    // Delay singkat agar UI feedback terlihat, lalu reconnect
    await Future.delayed(const Duration(milliseconds: 800));
    _connectMQTT();

    // Beri waktu koneksi agar ada feedback, lalu selesaikan refresh
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _connectMQTT();
  }

  void _showEmergencyDialog() {
    if (isSensorError) return;
    setState(() {
      isSensorError = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(Icons.gpp_bad_rounded, size: 60, color: Colors.red),
          title: const Text(
            'SYSTEM LOCKOUT',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: const Text(
            'Pompa dimatikan otomatis!\nTerdeteksi anomali/kerusakan pada kabel maket sensor fisik Anda.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'PULIHKAN ALAT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                setState(() {
                  isSensorError = false;
                  statusPompa = "MATI";
                });
                mqttHandler.publishMessage('irigasi/pompa_kontrol', '0');
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = statusKoneksi == "Terhubung";
    bool isPumpOn = statusPompa == "NYALA";

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F6),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 60,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[800]!, Colors.green[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AgroFlow Monitor',
                            style: TextStyle(
                              color: Colors.green[100],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Dashboard Utama',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.eco, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildQuickStatusTile(
                      icon: isConnected ? Icons.cloud_done : Icons.cloud_off,
                      label: statusKoneksi,
                      color: isConnected
                          ? Colors.tealAccent[400]!
                          : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 12),
                    _buildQuickStatusTile(
                      icon: isPumpOn ? Icons.water : Icons.water_drop_outlined,
                      label: 'Pompa: $statusPompa',
                      color: isPumpOn
                          ? Colors.blueAccent[100]!
                          : Colors.white60,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _onPullToRefresh,
              color: const Color(0xFF00FF87),
              backgroundColor: const Color(0xFF131520),
              strokeWidth: 3,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSensorError) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sistem Terkunci Darurat! Periksa kabel maket fisik.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 🚀 MODIFIKASI: Menambahkan Judul & Tombol Pindah Halaman Riwayat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Metrik Lingkungan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          // 🚀 Berpindah ke Halaman Riwayat
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text(
                          'Lihat Riwayat',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildInteractiveCard(
                    title: 'Suhu Udara',
                    value: suhu,
                    unit: '°C',
                    icon: Icons.thermostat_rounded,
                    color: Colors.orange,
                    progress: (double.tryParse(suhu) ?? 0.0) / 50.0,
                  ),
                  const SizedBox(height: 14),
                  _buildInteractiveCard(
                    title: 'Kelembapan Udara',
                    value: kelembapanUdara,
                    unit: '%',
                    icon: Icons.wb_cloudy_rounded,
                    color: Colors.blue,
                    progress: (double.tryParse(kelembapanUdara) ?? 0.0) / 100.0,
                  ),
                  const SizedBox(height: 14),
                  _buildInteractiveCard(
                    title: 'Kelembapan Tanah',
                    value: kelembapanTanah,
                    unit: '%',
                    icon: Icons.grass_rounded,
                    color: Colors.brown,
                    progress: (double.tryParse(kelembapanTanah) ?? 0.0) / 100.0,
                  ),

                  const SizedBox(height: 28),
                  const Text(
                    'Kendali Aktuator',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isPumpOn ? Colors.blue[50] : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.water_drop,
                          color: isPumpOn ? Colors.blue : Colors.grey,
                          size: 28,
                        ),
                      ),
                      title: const Text(
                        'Saklar Pompa Air',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        isPumpOn
                            ? 'Irigasi sedang menyiram ladang'
                            : 'Pompa dalam kondisi standby',
                      ),
                      trailing: Switch(
                        value: isPumpOn,
                        activeColor: Colors.blue,
                        onChanged: isSensorError
                            ? null
                            : (value) {
                                setState(() {
                                  statusPompa = value ? "NYALA" : "MATI";
                                });
                                mqttHandler.publishMessage(
                                  'irigasi/pompa_kontrol',
                                  value ? "1" : "0",
                                );
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildQuickStatusTile({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required double progress,
  }) {
    double cleanProgress = progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      value != "--" ? unit : "",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value != "--" ? cleanProgress : 0.0,
                    backgroundColor: Colors.grey[100],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🚀 HALAMAN BARU: HALAMAN LIST RIWAYAT DATA LOG DARI CLOUD FIRESTORE
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  Future<void> _onRefresh() async {
    // StreamBuilder Firestore sudah real-time, jadi cukup tunggu sebentar
    // sebagai visual feedback bahwa data sudah di-refresh
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color scaffoldBg = isDark ? const Color(0xFF090A0F) : const Color(0xFFF1F5F9);
    Color cardBg = isDark ? const Color(0xFF131520) : Colors.white;
    Color appBarBg = isDark ? const Color(0xFF131520) : Colors.teal;
    Color textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    Color textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Riwayat Data Sensor',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: appBarBg,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? const Color(0xFF1E2235) : Colors.black12,
            height: 1.0,
          ),
        ),
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _onRefresh,
        color: const Color(0xFF00FF87),
        backgroundColor: isDark ? const Color(0xFF131520) : Colors.white,
        strokeWidth: 3,
        child: StreamBuilder<QuerySnapshot>(
        // 🚀 Mengambil data dari koleksi Firestore, diurutkan dari yang paling baru masuk
        stream: FirebaseFirestore.instance
            .collection('history_agroflow')
            .orderBy('timestamp', descending: true)
            .limit(50) // Batasi 50 data teratas agar performa enteng
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}', style: TextStyle(color: textMain)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.history_toggle_off_rounded,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada riwayat data dari cloud.',
                    style: TextStyle(color: textSub),
                  ),
                ],
              ),
            );
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index].data() as Map<String, dynamic>;

              String sensorType = log['sensor_type'] ?? 'unknown';
              var value = log['value'] ?? '--';

              // Formatting Timestamp Firebase ke format jam lokal (WIB)
              String formatTime = '--:--';
              if (log['timestamp'] != null) {
                Timestamp t = log['timestamp'] as Timestamp;
                formatTime = DateFormat(
                  'dd MMM yyyy, HH:mm:ss',
                ).format(t.toDate());
              } else if (log['waktu_lokal'] != null) {
                // Cadangan jika timestamp server belum kelar di-generate
                DateTime dt = DateTime.parse(log['waktu_lokal']);
                formatTime = DateFormat('dd MMM yyyy, HH:mm:ss').format(dt);
              }

              // Pengkondisian Visual Ikon & Warna Berdasarkan Jenis Sensor
              IconData iconData = Icons.device_unknown;
              Color sensorColor = Colors.grey;
              String unit = '';
              String friendlyName = sensorType;

              if (sensorType == 'suhu') {
                iconData = Icons.thermostat_rounded;
                sensorColor = const Color(0xFFFF5E36); // Neon Orange
                unit = '°C';
                friendlyName = 'Suhu Udara';
              } else if (sensorType == 'kelembapan_udara') {
                iconData = Icons.wb_cloudy_rounded;
                sensorColor = const Color(0xFF00E5FF); // Neon Cyan
                unit = '%';
                friendlyName = 'Kelembapan Udara';
              } else if (sensorType == 'kelembapan_tanah') {
                iconData = Icons.grass_rounded;
                sensorColor = const Color(0xFF00FF87); // Neon Green
                unit = '%';
                friendlyName = 'Kelembapan Tanah';
              } else if (sensorType == 'status_pompa' ||
                  sensorType == 'pompa_kontrol') {
                iconData = Icons.water_drop;
                sensorColor = const Color(0xFFBF5AF2); // Neon Purple
                friendlyName = 'Status Saklar Pompa';
                value = (value == "1" || value == 1) ? "NYALA" : "MATI";
              }

              return Card(
                color: cardBg,
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF1E2235) : Colors.black54.withOpacity(0.01),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: sensorColor.withOpacity(0.1),
                    child: Icon(iconData, color: sensorColor),
                  ),
                  title: Text(
                    friendlyName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatTime,
                      style: TextStyle(color: textSub, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$value $unit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: sensorColor == Colors.grey
                            ? (isDark ? Colors.white70 : Colors.black87)
                            : sensorColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}

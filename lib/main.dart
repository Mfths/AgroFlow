import 'package:flutter/material.dart';
import 'mqtt_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // 🚀 UNTUK FORMAT TANGGAL DAN JAM
import 'firebase_options.dart';

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
    return MaterialApp(
      title: 'AgroFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        fontFamily: 'Sans-Serif',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/dashboard': (context) => const DashboardScreen(),
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
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[700],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'AgroFlow',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Smart Irrigation System',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ],
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

  @override
  void initState() {
    super.initState();
    mqttHandler.initializeMQTT(
      onConnected: () {
        setState(() {
          statusKoneksi = "Terhubung";
        });
        mqttHandler.subscribeToTopic('irigasi/suhu');
        mqttHandler.subscribeToTopic('irigasi/kelembapan_udara');
        mqttHandler.subscribeToTopic('irigasi/kelembapan_tanah');
        mqttHandler.subscribeToTopic('irigasi/pompa_kontrol');
        mqttHandler.subscribeToTopic('irigasi/status_pompa');
        mqttHandler.subscribeToTopic('irigasi/peringatan');
      },
      onMessageReceived: (topic, message) {
        simpanKeFirestore(topic, message);
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
      },
    );
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AgroFlow Monitor',
                          style: TextStyle(
                            color: Colors.green[100],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Text(
                          'Dashboard Utama',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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
            child: SingleChildScrollView(
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
                      const Text(
                        'Metrik Lingkungan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
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
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
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
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F6),
      appBar: AppBar(
        title: const Text(
          'Riwayat Data Sensor',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🚀 Mengambil data dari koleksi Firestore, diurutkan dari yang paling baru masuk
        stream: FirebaseFirestore.instance
            .collection('history_agroflow')
            .orderBy('timestamp', descending: true)
            .limit(50) // Batasi 50 data teratas agar performa enteng
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada riwayat data dari cloud.',
                    style: TextStyle(color: Colors.grey),
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
                sensorColor = Colors.orange;
                unit = '°C';
                friendlyName = 'Suhu Udara';
              } else if (sensorType == 'kelembapan_udara') {
                iconData = Icons.wb_cloudy_rounded;
                sensorColor = Colors.blue;
                unit = '%';
                friendlyName = 'Kelembapan Udara';
              } else if (sensorType == 'kelembapan_tanah') {
                iconData = Icons.grass_rounded;
                sensorColor = Colors.brown;
                unit = '%';
                friendlyName = 'Kelembapan Tanah';
              } else if (sensorType == 'status_pompa' ||
                  sensorType == 'pompa_kontrol') {
                iconData = Icons.water_drop;
                sensorColor = Colors.teal;
                friendlyName = 'Status Saklar Pompa';
                value = (value == "1" || value == 1) ? "NYALA" : "MATI";
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatTime,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                  trailing: Text(
                    '$value $unit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: sensorColor == Colors.grey
                          ? Colors.black87
                          : sensorColor,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

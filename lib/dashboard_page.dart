import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'mqtt_manager.dart';

class DashboardIrigasi extends StatefulWidget {
  const DashboardIrigasi({super.key});

  @override
  State<DashboardIrigasi> createState() => _DashboardIrigasiState();
}

class _DashboardIrigasiState extends State<DashboardIrigasi> {
  // ── DATA REAL-TIME DARI MQTT ──────────────────────────────────────────────
  double kelembapanTanah = 0.0;   // % dari topik irigasi/kelembapan_tanah
  double kelembapanUdara = 0.0;   // % dari topik irigasi/kelembapan_udara
  double suhuUdara = 0.0;         // °C dari topik irigasi/suhu
  bool isPompaNyala = false;      // dari topik irigasi/status_pompa SAJA
  bool isModeOtomatis = true;
  bool isSystemError = false;
  String statusKoneksi = "Menghubungkan...";

  // Menandai apakah data pertama sudah diterima (agar tidak tampil 0 sebelum konek)
  bool _dataReceived = false;
  bool _isRefreshing = false;

  // Menandai command pompa sedang "dikirim, menunggu konfirmasi device".
  // Dipakai supaya UI tidak menampilkan status seolah sudah pasti berubah
  // padahal ESP32 belum (atau tidak) mengonfirmasi lewat status_pompa.
  bool _pumpCommandPending = false;

  final MqttManager mqttHandler = MqttManager();

  // ── FIREBASE LOGGING ──────────────────────────────────────────────────────
  void _simpanKeFirestore(String topikAsli, String nilaiPayload) {
    final firestore = FirebaseFirestore.instance;
    final namaSensor = topikAsli.replaceAll('irigasi/', '');
    firestore.collection('history_agroflow').add({
      'sensor_type': namaSensor,
      'value': double.tryParse(nilaiPayload) ?? nilaiPayload,
      'timestamp': FieldValue.serverTimestamp(),
      'waktu_lokal': DateTime.now().toString(),
    }).catchError((e) {
      print('❌ Firebase error: $e');
      return Future<void>.value();
    });
  }

  // ── MQTT CONNECT ──────────────────────────────────────────────────────────
  void _connectMQTT() {
    if (mounted) {
      setState(() {
        statusKoneksi = "Menghubungkan...";
      });
    }

    mqttHandler.initializeMQTT(
      onConnected: () {
        if (mounted) {
          setState(() {
            statusKoneksi = "Terhubung ✓";
          });
        }
        mqttHandler.subscribeToTopic('irigasi/suhu');
        mqttHandler.subscribeToTopic('irigasi/kelembapan_udara');
        mqttHandler.subscribeToTopic('irigasi/kelembapan_tanah');
        // --- FIX: TIDAK subscribe ke 'irigasi/pompa_kontrol' lagi. ---
        // Topic ini adalah jalur COMMAND (app -> ESP32), bukan jalur
        // STATUS. Kalau app subscribe ke topic yang dia sendiri publish,
        // app akan menerima balik ("echo") perintahnya sendiri dan
        // menganggap itu sebagai konfirmasi bahwa ESP32 sudah benar-benar
        // mengeksekusi -- padahal ESP32 bisa saja MENGABAIKAN command itu
        // (misal karena mode di ESP32 ternyata otomatis, bukan manual).
        // Akibatnya UI bisa menampilkan "STANDBY" padahal pompa fisik
        // masih menyala.
        mqttHandler.subscribeToTopic('irigasi/status_pompa');
        mqttHandler.subscribeToTopic('irigasi/peringatan');
        // --- FIX: subscribe ke broadcast mode ASLI dari ESP32. ---
        // Ini beda dari topic 'irigasi/mode' (command app -> ESP32).
        // Topic ini adalah konfirmasi dari ESP32 sendiri tentang mode
        // yang BENAR-BENAR aktif di firmware saat ini -- dikirim ulang
        // setiap kali ESP32 connect/reconnect ke broker. Dengan ini, kalau
        // ESP32 reboot dan balik ke default 'otomatis' tanpa app sadar,
        // UI akan ikut tersinkron alih-alih tetap menampilkan state lama.
        mqttHandler.subscribeToTopic('irigasi/mode_status');
      },
      onMessageReceived: (topic, message) {
        // Simpan ke Firebase setiap ada data masuk
        _simpanKeFirestore(topic, message);

        if (!mounted) return;
        setState(() {
          _dataReceived = true;
          if (topic == 'irigasi/suhu') {
            suhuUdara = double.tryParse(message) ?? suhuUdara;
          } else if (topic == 'irigasi/kelembapan_udara') {
            kelembapanUdara = double.tryParse(message) ?? kelembapanUdara;
          } else if (topic == 'irigasi/kelembapan_tanah') {
            kelembapanTanah = double.tryParse(message) ?? kelembapanTanah;
          } else if (topic == 'irigasi/status_pompa') {
            // --- FIX: ini SATU-SATUNYA sumber kebenaran status pompa. ---
            // Pesan ini hanya dikirim ESP32 setelah dia benar-benar
            // mengubah kondisi relay, jadi aman dipercaya 100%.
            isPompaNyala = (message == "1" || message.toLowerCase() == "nyala");
            _pumpCommandPending = false; // konfirmasi sudah datang
          } else if (topic == 'irigasi/peringatan' && message == "BAHAYA") {
            _showEmergencyDialog();
          } else if (topic == 'irigasi/mode_status') {
            // Sumber kebenaran mode yang sebenarnya, dikonfirmasi langsung
            // dari ESP32 -- bukan asumsi dari command yang baru saja app
            // kirim sendiri.
            isModeOtomatis = (message == "otomatis");
          }
        });
      },
    );
  }

  // ── KIRIM COMMAND POMPA DENGAN FEEDBACK ───────────────────────────────────
  // Tidak langsung optimistic-update isPompaNyala di sini. UI akan
  // menampilkan status "Mengirim..." sampai status_pompa konfirmasi datang,
  // atau menampilkan error kalau command gagal terkirim sama sekali.
  void _kirimCommandPompa(bool nyalakan) {
    final berhasilKirim = mqttHandler.publishMessage(
      'irigasi/pompa_kontrol',
      nyalakan ? "1" : "0",
    );

    if (!berhasilKirim) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Gagal mengirim perintah. Cek koneksi internet.'),
            backgroundColor: Color(0xFFFF3366),
          ),
        );
      }
      return;
    }

    setState(() {
      _pumpCommandPending = true;
    });

    // Kalau dalam 6 detik tidak ada konfirmasi status_pompa balik,
    // anggap command kemungkinan diabaikan ESP32 (misal mode mismatch)
    // dan beri tahu user, daripada diam-diam menggantung selamanya.
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _pumpCommandPending) {
        setState(() => _pumpCommandPending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Tidak ada konfirmasi dari alat. '
              'Kemungkinan mode ESP32 tidak sinkron (cek mode manual/otomatis).',
            ),
            backgroundColor: Color(0xFFFF9500),
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  // ── PULL TO REFRESH: RECONNECT MQTT ───────────────────────────────────────
  Future<void> _onPullToRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _dataReceived = false;
      statusKoneksi = "Menghubungkan...";
    });

    try {
      mqttHandler.client.disconnect();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 600));
    _connectMQTT();
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // ── EMERGENCY DIALOG ──────────────────────────────────────────────────────
  void _showEmergencyDialog() {
    if (isSystemError) return;
    setState(() {
      isSystemError = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.gpp_bad_rounded, size: 60, color: Color(0xFFFF3366)),
        title: const Text(
          'SYSTEM LOCKOUT',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF3366)),
        ),
        content: const Text(
          'Pompa dimatikan otomatis!\nTerdeteksi anomali pada sensor fisik.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('PULIHKAN ALAT', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              setState(() {
                isSystemError = false;
              });
              // Tidak lagi optimistic-set isPompaNyala = false di sini;
              // tunggu konfirmasi asli dari status_pompa lewat _kirimCommandPompa.
              _kirimCommandPompa(false);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _connectMQTT();
  }

  @override
  void dispose() {
    try {
      mqttHandler.client.disconnect();
    } catch (_) {}
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color scaffoldBg =
        isDark ? const Color(0xFF090A0F) : const Color(0xFFF1F5F9);
    final Color cardBg = isDark ? const Color(0xFF131520) : Colors.white;
    final Color textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color textSub =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderCol =
        isDark ? const Color(0xFF1E2235) : const Color(0xFFE2E8F0);

    // Warna status berdasarkan kelembapan tanah real-time
    final Color statusColor = kelembapanTanah < 30
        ? const Color(0xFFFF3366)  // Neon Coral — kritis
        : const Color(0xFF00FF87); // Neon Green — normal

    final bool isConnected = statusKoneksi.contains("Terhubung");

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onPullToRefresh,
          color: statusColor,
          backgroundColor: isDark ? const Color(0xFF131520) : Colors.white,
          strokeWidth: 3,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER ────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Smart Irrigation",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textSub,
                            ),
                          ),
                          ValueListenableBuilder<String>(
                            valueListenable: userNameNotifier,
                            builder: (_, name, __) => Text(
                              "Halo, $name 👋",
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textMain,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Badge status koneksi MQTT
                    _buildStatusBadge(isConnected),
                  ],
                ),

                const SizedBox(height: 6),
                // Hint pull-to-refresh
                Center(
                  child: Text(
                    "↓ Tarik untuk reconnect MQTT",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: textSub.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── INDIKATOR KELEMBAPAN TANAH (LINGKARAN UTAMA) ──────────
                Center(
                  child: Column(
                    children: [
                      Text(
                        "Kelembapan Tanah",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textSub,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow shadow circle
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cardBg,
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor
                                      .withOpacity(isDark ? 0.4 : 0.15),
                                  blurRadius: 45,
                                  spreadRadius: isDark ? 6 : 0,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                          // Progress ring
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: CircularProgressIndicator(
                              value: _dataReceived
                                  ? (kelembapanTanah / 100).clamp(0.0, 1.0)
                                  : null, // indeterminate saat loading
                              strokeWidth: 12,
                              backgroundColor: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.grey.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            ),
                          ),
                          // Nilai tengah
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dataReceived
                                    ? "${kelembapanTanah.toStringAsFixed(1)}%"
                                    : "--",
                                style: GoogleFonts.poppins(
                                  fontSize: 44,
                                  fontWeight: FontWeight.bold,
                                  color: textMain,
                                ),
                              ),
                              Text(
                                _dataReceived
                                    ? (kelembapanTanah < 30
                                        ? "Kritis / Kering"
                                        : "Normal")
                                    : "Menunggu data...",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _dataReceived ? statusColor : textSub,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── GRID CARDS: SUHU & KELEMBAPAN UDARA ──────────────────
                Row(
                  children: [
                    Expanded(
                      child: _buildSensorCard(
                        title: "Suhu Udara",
                        value: _dataReceived
                            ? "${suhuUdara.toStringAsFixed(1)}°C"
                            : "--",
                        subtext: !_dataReceived
                            ? "Menunggu data..."
                            : suhuUdara > 30 ? "Cuaca Panas" : "Cuaca Adem",
                        icon: BoxedIcon(
                          WeatherIcons.thermometer,
                          color: const Color(0xFFFF5E36),
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSensorCard(
                        title: "Kelembapan Udara",
                        value: _dataReceived
                            ? "${kelembapanUdara.toStringAsFixed(1)}%"
                            : "--",
                        subtext: !_dataReceived
                            ? "Menunggu data..."
                            : kelembapanUdara > 70 ? "Lembap" : "Normal",
                        icon: const Icon(
                          Icons.water_drop_outlined,
                          color: Color(0xFF00E5FF),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── CARD STATUS POMPA ─────────────────────────────────────
                _buildPumpCard(cardBg, borderCol, textMain, textSub),
                const SizedBox(height: 24),

                // ── KONTROL MODE OTOMATIS / MANUAL ────────────────────────
                _buildModeControlCard(cardBg, borderCol, textMain, textSub),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── BADGE STATUS KONEKSI ─────────────────────────────────────────────────
  Widget _buildStatusBadge(bool isConnected) {
    final color = isConnected
        ? const Color(0xFF00FF87)
        : const Color(0xFFFF9500);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot animasi
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            isConnected ? "LIVE" : "Offline",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── PUMP STATUS CARD ─────────────────────────────────────────────────────
  Widget _buildPumpCard(Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final pumpColor = isPompaNyala ? const Color(0xFF00E5FF) : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
        boxShadow: isPompaNyala
            ? [BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                blurRadius: 20,
              )]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pumpColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.water_drop_rounded,
              color: pumpColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Status Pompa",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: textSub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _pumpCommandPending
                      ? "MENGIRIM..."
                      : (isPompaNyala ? "MENYIRAM 💧" : "STANDBY"),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _pumpCommandPending ? const Color(0xFFFF9500) : pumpColor,
                  ),
                ),
                Text(
                  _pumpCommandPending
                      ? "Menunggu konfirmasi dari alat..."
                      : (isPompaNyala
                          ? "Irigasi sedang berjalan"
                          : "Pompa dalam kondisi siaga"),
                  style: GoogleFonts.poppins(fontSize: 11, color: textSub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Toggle manual jika mode manual
          if (!isModeOtomatis)
            Switch(
              value: isPompaNyala,
              activeTrackColor: const Color(0xFF00E5FF).withOpacity(0.3),
              activeThumbColor: const Color(0xFF00E5FF),
              onChanged: (isSystemError || _pumpCommandPending)
                  ? null
                  : (val) {
                      // --- FIX: tidak optimistic-set isPompaNyala lagi.
                      // Tunggu konfirmasi asli dari status_pompa.
                      _kirimCommandPompa(val);
                    },
            ),
        ],
      ),
    );
  }

  // ── MODE OTOMATIS / MANUAL CONTROL CARD ──────────────────────────────────
  Widget _buildModeControlCard(Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFFBF5AF2), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mode Otomatis (Fuzzy)",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isModeOtomatis
                          ? "Dikendali kecerdasan ESP32"
                          : "Mode manual aktif",
                      style: GoogleFonts.poppins(fontSize: 12, color: textSub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: isModeOtomatis,
                activeTrackColor: const Color(0xFFBF5AF2).withOpacity(0.3),
                activeThumbColor: const Color(0xFFBF5AF2),
                onChanged: (val) {
                  final berhasil = mqttHandler.publishMessage(
                    'irigasi/mode',
                    val ? "otomatis" : "manual",
                  );
                  if (berhasil) {
                    setState(() => isModeOtomatis = val);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Gagal mengganti mode. Cek koneksi.'),
                        backgroundColor: Color(0xFFFF3366),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          // Tombol override manual jika mode manual aktif
          if (!isModeOtomatis) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPompaNyala
                    ? const Color(0xFFFF3366)
                    : const Color(0xFF00E5FF),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: isPompaNyala
                    ? const Color(0xFFFF3366).withOpacity(0.4)
                    : const Color(0xFF00E5FF).withOpacity(0.4),
              ),
              icon: Icon(
                isPompaNyala ? Icons.power_settings_new : Icons.water,
                size: 20,
              ),
              onPressed: (isSystemError || _pumpCommandPending)
                  ? null
                  : () {
                      // --- FIX: tidak optimistic-set isPompaNyala lagi.
                      _kirimCommandPompa(!isPompaNyala);
                    },
              label: Text(
                _pumpCommandPending
                    ? "MENGIRIM..."
                    : (isPompaNyala ? "MATIKAN POMPA" : "NYALAKAN POMPA"),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── SENSOR MINI CARD ─────────────────────────────────────────────────────
  Widget _buildSensorCard({
    required String title,
    required String value,
    required String subtext,
    required Widget icon,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF131520) : Colors.white;
    final Color textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color textSub =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderCol =
        isDark ? const Color(0xFF1E2235) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: textSub,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              icon,
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textMain,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtext,
            style: GoogleFonts.poppins(fontSize: 11, color: textSub),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
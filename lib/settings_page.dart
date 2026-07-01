import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'logo_widget.dart';
import 'main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Local controllers for edit dialogues
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brokerController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _brokerController.dispose();
    _portController.dispose();
    super.dispose();
  }

  // Helper method to build settings sections
  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 20, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Helper tile widget
  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black54.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.arrow_forward_ios_rounded, size: 16) : null),
        onTap: onTap,
      ),
    );
  }

  // Dialog to change user profile name
  void _showChangeNameDialog() {
    _nameController.text = userNameNotifier.value;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Ubah Nama Panggilan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: TextField(
          controller: _nameController,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: "Masukkan nama baru...",
            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
            ),
            focusedBorder: const BorderSide(color: Colors.teal).style == BorderStyle.solid
                ? const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2))
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (_nameController.text.trim().isNotEmpty) {
                userNameNotifier.value = _nameController.text.trim();
              }
              Navigator.pop(context);
            },
            child: Text(
              "Simpan",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog to edit MQTT config
  void _showMQTTConfigDialog() {
    _brokerController.text = mqttBrokerNotifier.value;
    _portController.text = mqttPortNotifier.value.toString();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Pengaturan Broker MQTT",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _brokerController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                labelText: "Broker Address",
                labelStyle: GoogleFonts.poppins(fontSize: 12),
                hintText: "e.g., broker.hivemq.com",
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                ),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                labelText: "Broker Port",
                labelStyle: GoogleFonts.poppins(fontSize: 12),
                hintText: "e.g., 1883",
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                ),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (_brokerController.text.trim().isNotEmpty) {
                mqttBrokerNotifier.value = _brokerController.text.trim();
              }
              final int? port = int.tryParse(_portController.text.trim());
              if (port != null) {
                mqttPortNotifier.value = port;
              }
              Navigator.pop(context);
            },
            child: Text(
              "Simpan",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog about app details
  void _showAboutAppDialog() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const AgroFlowLogo(size: 70, showShadow: true),
            const SizedBox(height: 16),
            Text(
              "AgroFlow Monitor",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              "Smart Irrigation System",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 24),
            Text(
              "Aplikasi monitoring irigasi pintar berbasis IoT dengan visualisasi data real-time, grafik histori sensor dari Firestore, dan kendali fuzzy logic pada mikrokontroler ESP32.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, height: 1.4),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("App Version", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                Text("v2.1.0", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Developer", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                Text("Mifta & Team", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Tutup",
                style: GoogleFonts.poppins(color: Colors.teal, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA);
    Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER SECTION ---
              Text(
                "Pengaturan",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              Text(
                "Kustomisasi aplikasi AgroFlow Anda",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),

              // --- LOGO SUMMARY CARD ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const AgroFlowLogo(size: 60, showShadow: false),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AgroFlow v2.1",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "IoT Smart Irrigation Monitor",
                            style: GoogleFonts.poppins(
                              color: Colors.tealAccent[100],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // --- TAMPILAN SECTION ---
              _buildSectionHeader("Sistem & Tampilan", isDark),

              // Dark Mode Switch Tile
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, themeMode, _) {
                  final isDarkEnabled = themeMode == ThemeMode.dark;
                  return _buildSettingsTile(
                    icon: Icons.dark_mode_rounded,
                    iconColor: Colors.deepPurpleAccent,
                    title: "Tema Gelap",
                    subtitle: "Ubah tampilan aplikasi ke mode gelap",
                    trailing: Switch(
                      value: isDarkEnabled,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                      },
                    ),
                  );
                },
              ),

              // Username Config Tile
              ValueListenableBuilder<String>(
                valueListenable: userNameNotifier,
                builder: (context, name, _) {
                  return _buildSettingsTile(
                    icon: Icons.person_rounded,
                    iconColor: Colors.teal,
                    title: "Nama Panggilan",
                    subtitle: name,
                    onTap: _showChangeNameDialog,
                  );
                },
              ),

              // --- NOTIFIKASI SECTION ---
              _buildSectionHeader("Notifikasi", isDark),

              // Emergency alert alerts switch tile
              ValueListenableBuilder<bool>(
                valueListenable: notificationNotifier,
                builder: (context, notificationsEnabled, _) {
                  return _buildSettingsTile(
                    icon: Icons.notifications_active_rounded,
                    iconColor: Colors.redAccent,
                    title: "Peringatan Darurat",
                    subtitle: "Bunyikan alarm & pop-up saat sistem bahaya",
                    trailing: Switch(
                      value: notificationsEnabled,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        notificationNotifier.value = val;
                      },
                    ),
                  );
                },
              ),

              // --- KONEKSI IOT SECTION ---
              _buildSectionHeader("Konfigurasi IoT", isDark),

              // MQTT configuration connection card
              ValueListenableBuilder<String>(
                valueListenable: mqttBrokerNotifier,
                builder: (context, broker, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: mqttPortNotifier,
                    builder: (context, port, _) {
                      return _buildSettingsTile(
                        icon: Icons.settings_ethernet_rounded,
                        iconColor: Colors.blueAccent,
                        title: "Server MQTT",
                        subtitle: "$broker : $port",
                        onTap: _showMQTTConfigDialog,
                      );
                    },
                  );
                },
              ),

              // --- TENTANG SECTION ---
              _buildSectionHeader("Info Aplikasi", isDark),

              _buildSettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: Colors.orangeAccent,
                title: "Tentang Aplikasi",
                subtitle: "Versi app, spesifikasi, dan lisensi",
                onTap: _showAboutAppDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

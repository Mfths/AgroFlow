import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Pastikan package ini tetap aman
import 'package:fl_chart/fl_chart.dart';

class HistoryIrigasi extends StatefulWidget {
  const HistoryIrigasi({Key? key}) : super(key: key);

  @override
  State<HistoryIrigasi> createState() => _HistoryIrigasiState();
}

class _HistoryIrigasiState extends State<HistoryIrigasi> {
  bool _isRefreshing = false;

  Future<void> _onPullToRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    // Simulasi data refresh (ganti dengan fetch Firebase/MQTT sesungguhnya)
    await Future.delayed(const Duration(seconds: 1, milliseconds: 500));
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
 }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA);
    Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textMain = isDark ? Colors.white : const Color(0xFF1E293B);
    Color textSub = isDark ? Colors.white70 : Colors.black54;
    Color borderCol = isDark ? Colors.white10 : Colors.black54.withOpacity(0.05);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onPullToRefresh,
          color: const Color(0xFF00FF87),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          strokeWidth: 3,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                "Analisis Data",
                style: GoogleFonts.poppins(fontSize: 14, color: textSub),
              ),
              Text(
                "Riwayat Sensor 📊",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 24),

              // --- GRAFIK FL_CHART ---
              Container(
                height: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pergerakan Kelembapan Tanah (%)",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  return Text(
                                    val.toInt().toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  return Text(
                                    val.toInt().toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                const FlSpot(0, 20),
                                const FlSpot(1, 28),
                                const FlSpot(2, 45),
                                const FlSpot(3, 60),
                                const FlSpot(4, 55),
                                const FlSpot(5, 70),
                              ],
                              isCurved: true,
                              color: const Color(0xFF00FF87),
                              barWidth: 4,
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color(0xFF00FF87).withOpacity(0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- LOG TIMELINE STEPPER SEDERHANA ---
              Text(
                "Aktivitas Terakhir",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 12),
              _buildLogTile(
                context,
                "12:00",
                "Pompa NYALA Otomatis (Tanah 28%)",
                Colors.green,
              ),
              _buildLogTile(
                context,
                "12:02",
                "Pompa MATI Otomatis (Tanah 65%)",
                Colors.blue,
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogTile(BuildContext context, String time, String desc, Color color) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textMain = isDark ? Colors.white : const Color(0xFF1E293B);
    Color textSub = isDark ? Colors.white54 : Colors.grey;

    return Card(
      elevation: 0,
      color: cardBg,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black54.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        leading: Icon(Icons.circle, color: color, size: 12),
        title: Text(
          desc,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textMain,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: textSub,
          ),
        ),
      ),
    );
  }
}

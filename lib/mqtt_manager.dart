import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttManager {
  final String server = "dd9629ab7d394679bed150e914cb2c0f.s1.eu.hivemq.cloud";
  final int port = 8883;

  final String mqttUser = "hivemq.webclient.1782117267462";
  final String mqttPass = "fC%AgT.>5J2aiY3dH!9p";

  late MqttServerClient client;

  // Simpan topik yang pernah di-subscribe, supaya bisa di-resubscribe manual
  // kalau resubscribeOnAutoReconnect ternyata tidak menutupi semua kasus.
  final List<String> _subscribedTopics = [];

  void initializeMQTT({
    required Function(String topic, String message) onMessageReceived,
    required Function() onConnected,
  }) async {
    String clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
    client = MqttServerClient.withPort(server, clientId, port);

    client.secure = true;
    client.securityContext = SecurityContext.defaultContext;
    client.onBadCertificate = (dynamic cert) => true;
    client.keepAlivePeriod = 20;
    client.logging(on: true);

    // --- FIX UTAMA: auto-reconnect ---
    // Tanpa ini, kalau koneksi putus sebentar (ganti wifi, app di-background,
    // sinyal HP lemah, dll), client akan diam di status disconnected
    // selamanya. Akibatnya semua publishMessage() setelah itu gagal total
    // secara silent, termasuk command "matikan pompa".
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;

    client.onConnected = onConnected;
    client.onDisconnected = () => print('❌ Terputus dari HiveMQ Broker.');
    client.onSubscribed = (String topic) => print('✅ Konfirmasi subscribe: $topic');
    client.onAutoReconnect = () => print('🔄 Mencoba auto-reconnect...');
    client.onAutoReconnected = () => print('✅ Auto-reconnect berhasil, koneksi pulih kembali.');

    final MqttConnectMessage connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .authenticateAs(mqttUser, mqttPass);

    client.connectionMessage = connMessage;

    try {
      print('⏳ Mencoba menghubungkan ke HiveMQ Cloud...');
      await client.connect();
    } catch (e) {
      print('❌ Error saat koneksi MQTT: $e');
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('✅ Status: CONNECTED ke HiveMQ');

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );
        print('📩 [MQTT MASUK] Topic: ${c[0].topic} | Pesan: $pt');
        onMessageReceived(c[0].topic, pt);
      });
    } else {
      print('⚠️ Status koneksi: ${client.connectionStatus}');
    }
  }

  void subscribeToTopic(String topic) {
    if (!_subscribedTopics.contains(topic)) {
      _subscribedTopics.add(topic);
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('📥 Subscribe ke topik: $topic');
      // Dinaikkan ke atLeastOnce supaya command dari broker (mis. status
      // pompa) tidak mudah hilang saat diterima sisi app.
      client.subscribe(topic, MqttQos.atLeastOnce);
    } else {
      print('⚠️ Gagal subscribe, client belum connected. Status: ${client.connectionStatus!.state}');
    }
  }

  /// Mengirim pesan MQTT.
  /// Return true kalau pesan berhasil dikirim ke broker, false kalau gagal
  /// (misal karena sedang disconnected). PENTING: cek return value ini di
  /// UI, jangan asumsikan command selalu berhasil hanya karena tombol
  /// di-tap.
  bool publishMessage(String topic, String message) {
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
      builder.addString(message);
      print('📤 Mengirim perintah ke $topic: $message');

      // --- FIX: QoS dinaikkan dari atMostOnce -> atLeastOnce ---
      // atMostOnce (QoS 0) = "kirim sekali, gak peduli nyampe atau gak".
      // Untuk data sensor itu oke karena terus dikirim ulang tiap beberapa
      // detik. Tapi untuk command kontrol (nyala/mati pompa) ini riskan:
      // sekali paket hilang karena gangguan jaringan sepersekian detik,
      // command itu hilang permanen tanpa retry.
      client.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
        retain: false, // pastikan TIDAK retain, supaya broker tidak
                        // mengirim ulang command lama (mis. "1") setiap
                        // kali ESP32 reconnect & subscribe ulang.
      );
      return true;
    } else {
      // --- FIX: dulu kalau disconnected, method ini diam total tanpa
      // error apapun. Sekarang minimal ke-print & return false, supaya
      // UI bisa kasih tahu user "command gagal, cek koneksi" daripada
      // diam-diam gagal dan UI sudah keburu optimistic-update jadi OFF.
      print('🚫 GAGAL KIRIM! Status koneksi: ${client.connectionStatus!.state}');
      return false;
    }
  }

  /// Cek cepat status koneksi saat ini, supaya UI bisa menampilkan
  /// indikator (misal titik merah/hijau) tanpa harus nebak-nebak.
  bool isConnected() {
    return client.connectionStatus?.state == MqttConnectionState.connected;
  }

  void disconnect() {
    client.disconnect();
  }
}
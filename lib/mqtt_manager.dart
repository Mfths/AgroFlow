import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttManager {
  final String server = "dd9629ab7d394679bed150e914cb2c0f.s1.eu.hivemq.cloud";
  final int port = 8883;

  final String mqttUser = "hivemq.webclient.1782117267462";
  final String mqttPass = "fC%AgT.>5J2aiY3dH!9p";

  late MqttServerClient client;

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

    client.onConnected = onConnected;
    client.onDisconnected = () => print('❌ Terputus dari HiveMQ Broker.');
    client.onSubscribed = (String topic) => print('✅ Konfirmasi subscribe: $topic');

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
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('📥 Subscribe ke topik: $topic');
      client.subscribe(topic, MqttQos.atMostOnce);
    } else {
      print('⚠️ Gagal subscribe, client belum connected. Status: ${client.connectionStatus!.state}');
    }
  }

  void publishMessage(String topic, String message) {
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
      builder.addString(message);
      print('📤 Mengirim perintah ke $topic: $message');
      client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    }
  }
}
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class NotificationService {
  String get baseUrl => '${AppConfig.baseUrl}/api/notification';

  Future<List<dynamic>> getUltimasNotificaciones() async {
    try {
      print('🔍 Intentando obtener notificaciones desde: $baseUrl');
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

      print('📡 Respuesta del servidor: ${response.statusCode}');
      print('📄 Cuerpo de respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notificaciones = data['notificaciones'] as List<dynamic>;
        print('✅ Notificaciones obtenidas: ${notificaciones.length}');
        return notificaciones;
      } else {
        print(
            '❌ Error del servidor: ${response.statusCode} - ${response.body}');
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getUltimasNotificaciones: $e');
      throw Exception('Error al obtener notificaciones: $e');
    }
  }

  Future<void> marcarComoLeida(String id, String userId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/marcar-leida/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId}),
    );

    print('📥 PATCH respuesta: ${response.statusCode} - ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Error al marcar como leída');
    }
  }
}

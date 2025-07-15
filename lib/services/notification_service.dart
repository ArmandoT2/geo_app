import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  final String baseUrl =
      'http://localhost:3000/api/notification'; // Ajusta a tu IP local o dominio

  Future<List<dynamic>> getUltimasNotificaciones() async {
    final response = await http.get(Uri.parse(baseUrl));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['notificaciones'];
    } else {
      throw Exception('Error al obtener notificaciones');
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

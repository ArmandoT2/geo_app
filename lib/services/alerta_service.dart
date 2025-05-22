import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alerta_model.dart';

class AlertaService {
  final String baseUrl = 'http://localhost:3000/api/alertas'; // Cambia IP

Future<List<Alerta>> obtenerAlertasPorUsuario(String userId) async {
  final response = await http.get(Uri.parse('$baseUrl/usuario/$userId'));
  print('Respuesta status: ${response.statusCode}');
  print('Respuesta body: ${response.body}');
  if (response.statusCode == 200) {
    final List<dynamic> body = json.decode(response.body);
    return body.map((e) => Alerta.fromJson(e)).toList();
  } else {
    throw Exception('Error al obtener alertas');
  }
}


Future<bool> crearAlerta(Alerta alerta) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/crear'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(alerta.toJson()), // ✅ aquí usamos toJson
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('Error al crear alerta: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error en la solicitud: $e');
      return false;
    }
  }
}

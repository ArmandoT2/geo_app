import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/alerta_model.dart';

class AlertaService {
  Future<List<Alerta>> obtenerAlertasPorUsuario(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.alertasUrl}/usuario/$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('Respuesta status: ${response.statusCode}');
      print('Respuesta body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> body = json.decode(response.body);
        final todasLasAlertas = body.map((e) => Alerta.fromJson(e)).toList();

        // Filtrar solo las alertas visibles para el ciudadano
        return todasLasAlertas.where((alerta) => alerta.visible).toList();
      } else {
        throw Exception('Error al obtener alertas: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerAlertasPorUsuario: $e');
      throw Exception('Error de conexión al obtener alertas');
    }
  }

  Future<bool> crearAlerta(Alerta alerta) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.crearAlertaUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(alerta.toJson()),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('Error al crear alerta: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error en crearAlerta: $e');
      return false;
    }
  }

  // Obtener alertas pendientes
  Future<List<Alerta>> obtenerAlertasPendientes() async {
    try {
      final response = await http
          .get(
            Uri.parse(AppConfig.alertasPendientesUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);

        // Debug: Imprimir datos recibidos del backend
        print('=== DEBUG BACKEND RESPONSE ===');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        print('Parsed Body Count: ${body.length}');

        if (body.isNotEmpty) {
          print('Primer elemento de ejemplo:');
          print(body.first);
        }

        return body.map((e) => Alerta.fromJson(e)).toList();
      } else {
        throw Exception(
          'Error al obtener alertas pendientes: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error en obtenerAlertasPendientes: $e');
      throw Exception('Error de conexión al obtener alertas pendientes');
    }
  }

  // Actualizar estado
  Future<bool> actualizarEstado(
    String alertaId,
    String nuevoEstado,
    String policiaId, {
    double? origenLat,
    double? origenLng,
    double? destinoLat,
    double? destinoLng,
    String? evidenciaUrl,
  }) async {
    final uri = Uri.parse('${AppConfig.alertasUrl}/$alertaId/status');

    final body = {
      'status': nuevoEstado,
      'policiaId': policiaId,
      if (origenLat != null &&
          origenLng != null &&
          destinoLat != null &&
          destinoLng != null)
        'origen': {'lat': origenLat, 'lng': origenLng},
      if (origenLat != null &&
          origenLng != null &&
          destinoLat != null &&
          destinoLng != null)
        'destino': {'lat': destinoLat, 'lng': destinoLng},
      if (evidenciaUrl != null) 'evidenciaUrl': evidenciaUrl,
    };

    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    print('📤 Código de respuesta: ${response.statusCode}');
    print('📤 Respuesta del servidor: ${response.body}');

    return response.statusCode == 200;
  }

  // Métodos para gestión administrativa de alertas
  Future<List<Alerta>> obtenerTodasLasAlertas() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.alertasUrl}/admin/todas'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((e) => Alerta.fromJson(e)).toList();
      } else {
        throw Exception(
          'Error al obtener todas las alertas: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error en obtenerTodasLasAlertas: $e');
      throw Exception('Error de conexión al obtener todas las alertas');
    }
  }

  Future<bool> ocultarAlerta(String alertaId) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConfig.alertasUrl}/$alertaId/ocultar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'visible': false}),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      return response.statusCode == 200;
    } catch (e) {
      print('Error en ocultarAlerta: $e');
      return false;
    }
  }

  Future<bool> restaurarAlerta(String alertaId) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConfig.alertasUrl}/$alertaId/restaurar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'visible': true}),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      return response.statusCode == 200;
    } catch (e) {
      print('Error en restaurarAlerta: $e');
      return false;
    }
  }

  Future<bool> actualizarAlerta(String alertaId, Alerta alerta) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConfig.alertasUrl}/$alertaId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(alerta.toJson()),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      return response.statusCode == 200;
    } catch (e) {
      print('Error en actualizarAlerta: $e');
      return false;
    }
  }
}

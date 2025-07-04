import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/alerta_model.dart';
import 'contacto_service.dart';

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
        // Alerta creada exitosamente, ahora notificar a los contactos
        try {
          final responseData = jsonDecode(response.body);
          final alertaId = responseData['id']?.toString() ?? alerta.id;

          final contactoService = ContactoService();
          await contactoService.notificarContactosAlerta(
            usuarioId: alerta.usuarioCreador,
            alertaId: alertaId,
            tipoAlerta: 'emergencia',
            detalle: alerta.detalle,
            latitud: alerta.lat,
            longitud: alerta.lng,
          );

          print('✅ Contactos notificados correctamente');
        } catch (e) {
          print('⚠️ Alerta creada pero error al notificar contactos: $e');
          // No fallar la creación de la alerta por errores de notificación
        }

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
  }) async {
    try {
      Map<String, dynamic> body = {
        'status': nuevoEstado,
        'policiaId': policiaId,
      };

      if (origenLat != null &&
          origenLng != null &&
          destinoLat != null &&
          destinoLng != null) {
        body['origen'] = {'lat': origenLat, 'lng': origenLng};
        body['destino'] = {'lat': destinoLat, 'lng': destinoLng};
      }

      final response = await http
          .put(
            Uri.parse('${AppConfig.alertasUrl}/$alertaId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      return response.statusCode == 200;
    } catch (e) {
      print('Error en actualizarEstado: $e');
      return false;
    }
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

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/contacto_model.dart';

class ContactoService {
  // Obtener todos los contactos de un usuario
  Future<List<Contacto>> obtenerContactos(String usuarioId) async {
    // Modo de desarrollo con datos simulados
    if (AppConfig.useMockData) {
      await Future.delayed(Duration(milliseconds: 500)); // Simular latencia
      return _getMockContactos(usuarioId);
    }

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiUrl}/contactos/usuario/$usuarioId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('Respuesta contactos status: ${response.statusCode}');
      print('Respuesta contactos body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> body = json.decode(response.body);
        return body.map((e) => Contacto.fromJson(e)).toList();
      } else {
        throw Exception('Error al obtener contactos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerContactos: $e');
      // En modo desarrollo, devolver datos mock si falla la conexión
      if (AppConfig.developmentMode) {
        print('🔄 Usando datos simulados por error de conexión');
        return _getMockContactos(usuarioId);
      }
      throw Exception('Error de conexión al obtener contactos');
    }
  }

  // Crear un nuevo contacto
  Future<Contacto?> crearContacto(Contacto contacto) async {
    // Modo de desarrollo con datos simulados
    if (AppConfig.useMockData) {
      await Future.delayed(Duration(milliseconds: 800)); // Simular latencia
      print('✅ Contacto creado (simulado): ${contacto.nombreCompleto}');
      return contacto.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fechaCreacion: DateTime.now(),
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.apiUrl}/contactos'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(contacto.toJson()),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('Crear contacto status: ${response.statusCode}');
      print('Crear contacto body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        return Contacto.fromJson(body);
      } else {
        throw Exception('Error al crear contacto: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en crearContacto: $e');
      // En modo desarrollo, simular éxito
      if (AppConfig.developmentMode) {
        print('🔄 Simulando creación de contacto por error de conexión');
        return contacto.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fechaCreacion: DateTime.now(),
        );
      }
      throw Exception('Error de conexión al crear contacto');
    }
  }

  // Actualizar un contacto existente
  Future<Contacto?> actualizarContacto(Contacto contacto) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConfig.apiUrl}/contactos/${contacto.id}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(contacto.toJson()),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('Actualizar contacto status: ${response.statusCode}');
      print('Actualizar contacto body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        return Contacto.fromJson(body);
      } else {
        throw Exception('Error al actualizar contacto: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en actualizarContacto: $e');
      throw Exception('Error de conexión al actualizar contacto');
    }
  }

  // Eliminar un contacto
  Future<bool> eliminarContacto(String contactoId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${AppConfig.apiUrl}/contactos/$contactoId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('Eliminar contacto status: ${response.statusCode}');
      print('Eliminar contacto body: ${response.body}');

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error en eliminarContacto: $e');
      throw Exception('Error de conexión al eliminar contacto');
    }
  }

  // Notificar a los contactos cuando se emite una alerta
  Future<bool> notificarContactosAlerta({
    required String usuarioId,
    required String alertaId,
    required String tipoAlerta,
    required String detalle,
    required double? latitud,
    required double? longitud,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'usuario_id': usuarioId,
        'alerta_id': alertaId,
        'tipo_alerta': tipoAlerta,
        'detalle': detalle,
        'latitud': latitud,
        'longitud': longitud,
        'fecha_hora': DateTime.now().toIso8601String(),
      };

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiUrl}/contactos/notificar-alerta'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('Notificar contactos status: ${response.statusCode}');
      print('Notificar contactos body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Error en notificarContactosAlerta: $e');
      throw Exception('Error de conexión al notificar contactos');
    }
  }

  // Obtener notificaciones pendientes para un usuario
  Future<List<Map<String, dynamic>>> obtenerNotificacionesPendientes(
    String usuarioId,
  ) async {
    // Modo de desarrollo con datos simulados
    if (AppConfig.useMockData) {
      await Future.delayed(Duration(milliseconds: 600)); // Simular latencia
      return _getMockNotificaciones(usuarioId);
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.apiUrl}/contactos/notificaciones/$usuarioId',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('Notificaciones pendientes status: ${response.statusCode}');
      print('Notificaciones pendientes body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> body = json.decode(response.body);
        return body.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
          'Error al obtener notificaciones: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error en obtenerNotificacionesPendientes: $e');
      // En modo desarrollo, devolver datos mock si falla la conexión
      if (AppConfig.developmentMode) {
        print('🔄 Usando notificaciones simuladas por error de conexión');
        return _getMockNotificaciones(usuarioId);
      }
      throw Exception('Error de conexión al obtener notificaciones');
    }
  }

  // Marcar notificación como leída
  Future<bool> marcarNotificacionLeida(String notificacionId) async {
    try {
      final response = await http
          .patch(
            Uri.parse(
              '${AppConfig.apiUrl}/contactos/notificaciones/$notificacionId/leida',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('Marcar notificación leída status: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      print('Error en marcarNotificacionLeida: $e');
      return false;
    }
  }

  // Activar/desactivar notificaciones para un contacto
  Future<bool> toggleNotificaciones(String contactoId, bool activas) async {
    try {
      final response = await http
          .patch(
            Uri.parse(
              '${AppConfig.apiUrl}/contactos/$contactoId/notificaciones',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'notificaciones_activas': activas}),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('Toggle notificaciones status: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      print('Error en toggleNotificaciones: $e');
      return false;
    }
  }

  // ========== MÉTODOS DE DESARROLLO / DATOS SIMULADOS ==========

  List<Contacto> _getMockContactos(String usuarioId) {
    return [
      Contacto(
        id: '1',
        nombre: 'María',
        apellido: 'González',
        telefono: '+593987654321',
        email: 'maria.gonzalez@email.com',
        relacion: 'familiar',
        usuarioId: usuarioId,
        notificacionesActivas: true,
        fechaCreacion: DateTime.now().subtract(Duration(days: 30)),
      ),
      Contacto(
        id: '2',
        nombre: 'Carlos',
        apellido: 'Pérez',
        telefono: '+593998765432',
        email: 'carlos.perez@email.com',
        relacion: 'amigo',
        usuarioId: usuarioId,
        notificacionesActivas: true,
        fechaCreacion: DateTime.now().subtract(Duration(days: 15)),
      ),
      Contacto(
        id: '3',
        nombre: 'Ana',
        apellido: 'Rodríguez',
        telefono: '+593912345678',
        relacion: 'emergencia',
        usuarioId: usuarioId,
        notificacionesActivas: false,
        fechaCreacion: DateTime.now().subtract(Duration(days: 7)),
      ),
    ];
  }

  List<Map<String, dynamic>> _getMockNotificaciones(String usuarioId) {
    // Lista vacía - las notificaciones se crearán vía API real
    return [];
  }
}

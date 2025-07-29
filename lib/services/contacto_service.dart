import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/contacto_model.dart';

class ContactoService {
  Future<List<Contacto>> obtenerContactos(String usuarioId) async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.contactosUrl}/usuario/$usuarioId'))
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('📞 Respuesta obtener contactos: ${response.statusCode}');
      print('📞 Cuerpo respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData['contactos'];
        return data.map((e) => Contacto.fromJson(e)).toList();
      } else {
        throw Exception('Error al obtener contactos: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en obtenerContactos: $e');
      throw Exception('Error de conexión al obtener contactos: $e');
    }
  }

  Future<Contacto?> crearContacto(Contacto contacto) async {
    try {
      print('📞 Creando contacto: ${contacto.toJson()}');

      final response = await http
          .post(
            Uri.parse('${AppConfig.contactosUrl}/crear'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(contacto.toJson()),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('📞 Respuesta crear contacto: ${response.statusCode}');
      print('📞 Cuerpo respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return Contacto.fromJson(responseData['contacto']);
      } else {
        throw Exception('Error al crear contacto: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en crearContacto: $e');
      throw Exception('Error de conexión al crear contacto: $e');
    }
  }

  Future<Contacto?> actualizarContacto(Contacto contacto) async {
    try {
      print('📞 Actualizando contacto: ${contacto.toJson()}');

      final response = await http
          .put(
            Uri.parse('${AppConfig.contactosUrl}/${contacto.id}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(contacto.toJson()),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('📞 Respuesta actualizar contacto: ${response.statusCode}');
      print('📞 Cuerpo respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return Contacto.fromJson(responseData['contacto']);
      } else {
        throw Exception('Error al actualizar contacto: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en actualizarContacto: $e');
      throw Exception('Error de conexión al actualizar contacto: $e');
    }
  }

  Future<bool> eliminarContacto(String id) async {
    try {
      print('📞 Eliminando contacto: $id');

      final response = await http
          .delete(Uri.parse('${AppConfig.contactosUrl}/$id'))
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('📞 Respuesta eliminar contacto: ${response.statusCode}');
      print('📞 Cuerpo respuesta: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Error al eliminar contacto: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en eliminarContacto: $e');
      throw Exception('Error de conexión al eliminar contacto: $e');
    }
  }

  Future<bool> toggleNotificaciones(String id, bool estado) async {
    try {
      print('📞 Cambiando notificaciones contacto $id a: $estado');

      final response = await http
          .patch(
            Uri.parse('${AppConfig.contactosUrl}/$id/notificaciones'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'estado': estado}),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      print('📞 Respuesta toggle notificaciones: ${response.statusCode}');
      print('📞 Cuerpo respuesta: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
            'Error al cambiar notificaciones: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en toggleNotificaciones: $e');
      throw Exception('Error de conexión al cambiar notificaciones: $e');
    }
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';

class UserService {
  static Future<List<User>> getUsuarios() async {
    try {
      final response = await http
          .get(
            Uri.parse(AppConfig.usuariosUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener usuarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getUsuarios: $e');
      throw Exception('Error de conexión al obtener usuarios');
    }
  }

  static Future<bool> crearUsuario(Map<String, dynamic> userData) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.usuariosUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(userData),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      return response.statusCode == 201;
    } catch (e) {
      print('Error en crearUsuario: $e');
      return false;
    }
  }

  static Future<bool> editarUsuario(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConfig.usuariosUrl}/$userId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(userData),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      return response.statusCode == 200;
    } catch (e) {
      print('Error en editarUsuario: $e');
      return false;
    }
  }

  // Obtener datos del usuario actual
  static Future<User?> obtenerUsuarioActual(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.usuariosUrl}/$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return User.fromJson(data);
      } else {
        throw Exception('Error al obtener usuario: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerUsuarioActual: $e');
      throw Exception('Error de conexión al obtener usuario');
    }
  }

  // Actualizar datos del usuario ciudadano
  static Future<bool> actualizarDatosCiudadano(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      // Asegurar que el rol sea 'ciudadano' para migrar usuarios antiguos con 'cliente'
      userData['rol'] = 'ciudadano';

      final response = await http
          .put(
            Uri.parse('${AppConfig.usuariosUrl}/$userId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(userData),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      // Si la actualización fue exitosa, actualizar también el rol en SharedPreferences
      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('rol', 'ciudadano');
      }

      return response.statusCode == 200;
    } catch (e) {
      print('Error en actualizarDatosCiudadano: $e');
      return false;
    }
  }

  // Cambiar contraseña
  static Future<bool> cambiarContrasena(
    String userId,
    String contrasenaActual,
    String contrasenaNueva,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConfig.usuariosUrl}/$userId/cambiar-password'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'currentPassword': contrasenaActual,
              'newPassword': contrasenaNueva,
            }),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      return response.statusCode == 200;
    } catch (e) {
      print('Error en cambiarContrasena: $e');
      return false;
    }
  }

  // Eliminar cuenta del ciudadano (soft delete)
  static Future<bool> eliminarCuentaCiudadano(
    String userId,
    String contrasena,
  ) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${AppConfig.usuariosUrl}/$userId/eliminar-cuenta'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'password': contrasena,
              'preserveAlerts': true, // Conservar alertas para registros
            }),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      return response.statusCode == 200;
    } catch (e) {
      print('Error en eliminarCuentaCiudadano: $e');
      return false;
    }
  }
}

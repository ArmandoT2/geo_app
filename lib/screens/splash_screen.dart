import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    // Mostrar configuración de debug
    if (AppConfig.developmentMode) {
      AppConfig.printConfig();
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email');
      final userId = prefs.getString('userId'); // Corregido: era '_id'
      final userRol = prefs.getString('rol');

      print(
        'SplashScreen - Email: $email, UserId: $userId, Rol: $userRol',
      ); // Debug

      // Migración automática de rol "cliente" a "ciudadano"
      if (userRol == 'cliente' && userId != null) {
        await prefs.setString('rol', 'ciudadano');
        _migrarRolUsuario(userId);
        print('Rol migrado de cliente a ciudadano');
      }

      if (email != null &&
          email.isNotEmpty &&
          userId != null &&
          userId.isNotEmpty &&
          userRol != null &&
          userRol.isNotEmpty) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error en checkLoginStatus: $e');
      // En caso de error, ir al login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // Método para migrar usuarios con rol "cliente" a "ciudadano"
  Future<void> _migrarRolUsuario(String userId) async {
    try {
      await http.put(
        Uri.parse('${AppConfig.usuariosUrl}/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rol': 'ciudadano'}),
      );
      print('Rol migrado de cliente a ciudadano para usuario $userId');
    } catch (e) {
      print('Error al migrar rol: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

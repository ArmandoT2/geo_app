import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  // Configuración simplificada para Android
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (Platform.isAndroid) {
      // Siempre usar 10.0.2.2 para Android (funciona tanto en emulador como dispositivo)
      return 'http://10.0.2.2:3000';
    } else if (Platform.isIOS) {
      return 'http://localhost:3000';
    } else {
      return 'http://localhost:3000';
    }
  }

  static String get apiUrl => '$baseUrl/api';

  // Endpoints de autenticación
  static String get loginUrl => '$apiUrl/auth/login';
  static String get registerUrl => '$apiUrl/auth/register';
  static String get changePasswordUrl => '$apiUrl/auth/change-password';

  // Endpoints de alertas
  static String get alertasUrl => '$apiUrl/alertas';
  static String get crearAlertaUrl => '$alertasUrl/crear';
  static String get alertasPendientesUrl => '$alertasUrl/pendientes';

  // Endpoints de contactos y notificaciones
  static String get contactosUrl => '$apiUrl/contactos';
  static String get notificacionesUrl => '$apiUrl/notificaciones';

  // Endpoints de usuarios
  static String get usuariosUrl => '$baseUrl/usuarios';

  // Configuraciones de mapa
  static const String mapTileUrl =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const List<String> mapSubdomains = ['a', 'b', 'c'];

  // Configuraciones por defecto
  static const double defaultLat = -0.1806; // Quito, Ecuador
  static const double defaultLng = -78.4678;

  // Timeouts
  static const int connectionTimeout = 30; // segundos
  static const int receiveTimeout = 30; // segundos

  // Modo desarrollo (sin backend)
  static const bool developmentMode = true;
  static const bool useMockData = true;

  // Función de debug para mostrar la configuración actual
  static void printConfig() {
    print('🔧 AppConfig Debug Info:');
    print('Is Web: $kIsWeb');
    if (!kIsWeb) {
      print('Platform: ${Platform.operatingSystem}');
    }
    print('Base URL: $baseUrl');
    print('API URL: $apiUrl');
    print('Login URL: $loginUrl');
  }
}

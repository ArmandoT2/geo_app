import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  // Configuración simplificada para Android
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (Platform.isAndroid) {
      // Usar IP de la máquina para conexión desde emulador
      return 'http://192.168.100.124:3000';
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

  // Endpoints de alertas
  static String get alertasUrl => '$apiUrl/alertas';
  static String get crearAlertaUrl => '$alertasUrl/crear';
  static String get alertasPendientesUrl => '$alertasUrl/pendientes';

  // Endpoints de contactos y notificaciones
  static String get contactosUrl => '$apiUrl/contactos';
  static String get notificacionesUrl => '$apiUrl/notificaciones';

  // Endpoints de usuarios
  static String get usuariosUrl => '$baseUrl/usuarios';
  static String get changePasswordUrl => '$usuariosUrl/cambiar-password';

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
  static const bool developmentMode = false;
  static const bool useMockData = false;

  // Función de debug para mostrar la configuración actual
  static void printConfig() {
    print('🔧 AppConfig Debug Info - Updated:');
    print('Is Web: $kIsWeb');
    if (!kIsWeb) {
      print('Platform: ${Platform.operatingSystem}');
    }
    print('Base URL: $baseUrl');
    print('API URL: $apiUrl');
    print('Login URL: $loginUrl');
    print('Change Password URL: $changePasswordUrl');
  }
}

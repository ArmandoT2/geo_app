// lib/main.dart
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'screens/splash_screen.dart';

void main() {
  // Mostrar configuración de debug en modo desarrollo
  if (AppConfig.developmentMode) {
    AppConfig.printConfig();
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Alertas',
      debugShowCheckedModeBanner: false,
      theme: appTheme, // Aplica el tema personalizado
      initialRoute: '/',
      routes: {'/': (_) => SplashScreen(), ...appRoutes},
    );
  }
}

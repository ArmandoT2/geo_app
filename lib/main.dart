import 'package:flutter/material.dart';

import 'config/routes.dart';
import 'config/theme.dart'; // Importa tu archivo de tema
import 'screens/splash_screen.dart';

void main() => runApp(MyApp());

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

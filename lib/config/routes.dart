// lib/routes/route.dart
import 'package:flutter/material.dart';
import 'package:geo_app/screens/crear_usuario_screen.dart';
import 'package:geo_app/screens/editar_usuario_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/home_screen.dart';
import '../screens/gestion_usuarios_screen.dart';
import '../screens/alert_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/login': (context) => LoginScreen(),
  '/register': (context) => RegisterScreen(),
  '/change-password': (context) => ChangePasswordScreen(),
  '/home': (context) => HomeScreen(),
  '/gestion-usuarios': (context) => GestionUsuariosScreen(),
  '/crear-usuario': (_) => CrearUsuarioScreen(),
  '/editar-usuario': (_) => EditarUsuarioScreen(),
  '/crear-alerta': (context) {
    final userId = ModalRoute.of(context)!.settings.arguments as String? ?? '';
    return AlertaListScreen(userId: userId);
  },

  // '/atender-alerta': (context) => AtenderAlertaScreen(),
};

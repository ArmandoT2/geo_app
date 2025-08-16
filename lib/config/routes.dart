// lib/config/routes.dart
import 'package:flutter/material.dart';
import 'package:geo_app/screens/reportes_alertas_screen.dart';

import '../screens/actualizar_datos_screen.dart';
import '../screens/alert_screen.dart';
import '../screens/alerta_form_screen.dart';
import '../screens/alerta_police_screen.dart';
import '../screens/alertas_atendidas_screen.dart';
import '../screens/cambiar_contrasena_admin_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/configuraciones_ciudadano_screen.dart';
import '../screens/contactos_screen.dart';
import '../screens/crear_usuario_screen.dart';
import '../screens/editar_usuario_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/gestion_alertas_screen.dart';
import '../screens/gestion_usuarios_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notificaciones_screen.dart';
import '../screens/register_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/login': (context) => LoginScreen(),
  '/register': (context) => RegisterScreen(),
  '/change-password': (context) => ChangePasswordScreen(),
  '/forgot-password': (context) => ForgotPasswordScreen(),
  '/home': (context) => HomeScreen(),
  '/gestion-usuarios': (context) => GestionUsuariosScreen(),
  '/gestion-alertas': (context) => GestionAlertasScreen(),
  '/actualizar-datos': (context) => ActualizarDatosScreen(),
  '/configuraciones-ciudadano': (context) => ConfiguracionesCiudadanoScreen(),
  '/crear-usuario': (_) => CrearUsuarioScreen(),
  '/editar-usuario': (_) => EditarUsuarioScreen(),
  '/cambiar-contrasena-admin': (_) => CambiarContrasenaAdminScreen(),
  '/crear-alerta': (context) {
    final userId = ModalRoute.of(context)!.settings.arguments as String? ?? '';
    return AlertaFormScreen(userId: userId);
  },
  '/alertas-list': (context) {
    final userId = ModalRoute.of(context)!.settings.arguments as String? ?? '';
    return AlertaListScreen(userId: userId);
  },
  '/atender-alerta': (_) => AlertaPoliceScreen(),
  '/alertas-atendidas': (context) => const AlertasAtendidasScreen(),
  '/contactos': (_) => ContactosScreen(),
  '/notificaciones': (_) => NotificacionesScreen(),
  '/reportes-alertas': (_) => ReportesAlertasScreen(),
};

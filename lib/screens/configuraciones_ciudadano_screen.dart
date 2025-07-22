import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'eliminar_cuenta_screen.dart';

class ConfiguracionesCiudadanoScreen extends StatefulWidget {
  const ConfiguracionesCiudadanoScreen({super.key});

  @override
  State<ConfiguracionesCiudadanoScreen> createState() =>
      _ConfiguracionesCiudadanoScreenState();
}

class _ConfiguracionesCiudadanoScreenState
    extends State<ConfiguracionesCiudadanoScreen> {
  User? _usuario;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      final email = prefs.getString('email') ?? '';
      final username = prefs.getString('username') ?? '';
      final fullName = prefs.getString('fullName') ?? '';
      final phone = prefs.getString('phone') ?? '';
      final address = prefs.getString('address') ?? '';
      final genero = prefs.getString('genero') ?? 'masculino';
      final rol = prefs.getString('rol') ?? '';

      if (userId.isNotEmpty) {
        _usuario = User(
          id: userId,
          username: username,
          fullName: fullName,
          email: email,
          phone: phone,
          address: address,
          genero: genero,
          rol: rol,
        );
      }
    } catch (e) {
      print('Error al cargar datos: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _navegarAEliminarCuenta() {
    if (_usuario != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EliminarCuentaScreen(usuario: _usuario!),
        ),
      );
    }
  }

  void _mostrarDialogoConfirmacion() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Desactivar Cuenta'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta acción desactivará tu cuenta',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Al desactivar tu cuenta:\n'
                '• Perderás acceso a la aplicación\n'
                '• Tus datos personales serán protegidos\n'
                '• Tus alertas SE CONSERVARÁN para fines de seguridad\n'
                '• No podrás recuperar tu cuenta sin ayuda del administrador',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tus alertas permanecen para seguridad ciudadana',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _navegarAEliminarCuenta();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Continuar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Cuenta'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _usuario == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text('No se pudieron cargar los datos del usuario'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                      child: Text('Volver al Login'),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con información del usuario
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.blue,
                              child: Text(
                                _usuario!.fullName.isNotEmpty
                                    ? _usuario!.fullName[0].toUpperCase()
                                    : _usuario!.username[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _usuario!.fullName.isNotEmpty
                                        ? _usuario!.fullName
                                        : _usuario!.username,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _usuario!.email,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Sección de Configuraciones de Cuenta
                    Text(
                      'Configuraciones de Cuenta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Opción Desactivar Cuenta
                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          child: Icon(Icons.delete_forever, color: Colors.red),
                        ),
                        title: Text(
                          'Desactivar Cuenta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.red[700],
                          ),
                        ),
                        subtitle: Text(
                          'Desactivar tu cuenta (tus alertas se conservan para seguridad)',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.red,
                        ),
                        onTap: _mostrarDialogoConfirmacion,
                      ),
                    ),

                    SizedBox(height: 24),

                    // Información de Seguridad
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, color: Colors.blue[700]),
                              SizedBox(width: 8),
                              Text(
                                'Información de Seguridad',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            '• Tus datos están protegidos con encriptación\n'
                            '• Las alertas que hayas creado PERMANECERÁN en el sistema\n'
                            '• Esto permite generar reportes de seguridad ciudadana\n'
                            '• Tu cuenta será desactivada, no eliminada físicamente\n'
                            '• Si tienes dudas, contacta al soporte técnico',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Información de contacto de soporte
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.support_agent,
                                color: Colors.green[700],
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Soporte Técnico',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Si necesitas ayuda o tienes alguna duda sobre la desactivación de tu cuenta, puedes contactarnos. También podemos reactivar tu cuenta si es necesario.',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

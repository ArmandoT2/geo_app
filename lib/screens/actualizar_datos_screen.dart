import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'change_password_screen.dart';
import 'editar_perfil_screen.dart';
import 'eliminar_cuenta_screen.dart';

class ActualizarDatosScreen extends StatefulWidget {
  const ActualizarDatosScreen({super.key});

  @override
  State<ActualizarDatosScreen> createState() => _ActualizarDatosScreenState();
}

class _ActualizarDatosScreenState extends State<ActualizarDatosScreen> {
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
      final genero =
          prefs.getString('genero') ?? 'masculino'; // Campo género agregado
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

  String _getInitial(String name) {
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  void _navegarAEditarPerfil() {
    if (_usuario != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditarPerfilScreen(usuario: _usuario!),
        ),
      ).then((resultado) {
        if (resultado == true) {
          _cargarDatosUsuario();
        }
      });
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

  void _navegarACambiarContrasena() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChangePasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actualizar Datos'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargarDatosUsuario),
        ],
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
                    // Información del usuario
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  child: Text(
                                    _getInitial(
                                      _usuario!.fullName.isNotEmpty
                                          ? _usuario!.fullName
                                          : _usuario!.username,
                                    ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _usuario!.fullName.isNotEmpty
                                            ? _usuario!.fullName
                                            : _usuario!.username,
                                        style: TextStyle(
                                          fontSize: 20,
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
                            Divider(height: 24),
                            _buildInfoRow(
                              Icons.person,
                              'Usuario',
                              _usuario!.username,
                            ),
                            _buildInfoRow(
                              Icons.phone,
                              'Teléfono',
                              _usuario!.phone.isEmpty
                                  ? 'No especificado'
                                  : _usuario!.phone,
                            ),
                            _buildInfoRow(
                              Icons.location_on,
                              'Dirección',
                              _usuario!.address.isEmpty
                                  ? 'No especificada'
                                  : _usuario!.address,
                            ),
                            _buildInfoRow(
                              Icons.person_outline,
                              'Género',
                              _usuario!.genero.isEmpty
                                  ? 'No especificado'
                                  : _usuario!.genero
                                          .substring(0, 1)
                                          .toUpperCase() +
                                      _usuario!.genero.substring(1),
                            ),
                            _buildInfoRow(
                              Icons.admin_panel_settings,
                              'Rol',
                              _usuario!.rol,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    Text(
                      'Opciones disponibles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Botón Editar Perfil
                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: Icon(Icons.edit, color: Colors.blue),
                        ),
                        title: Text(
                          'Editar Perfil',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text('Actualizar información personal'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _navegarAEditarPerfil,
                      ),
                    ),

                    SizedBox(height: 8),

                    // Botón Cambiar Contraseña - Solo para ciudadanos
                    if (_usuario!.rol == 'ciudadano')
                      Card(
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.withOpacity(0.1),
                            child: Icon(Icons.lock, color: Colors.green),
                          ),
                          title: Text(
                            'Cambiar Contraseña',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text('Actualizar tu contraseña de acceso'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _navegarACambiarContrasena,
                        ),
                      ),

                    if (_usuario!.rol == 'ciudadano') SizedBox(height: 8),

                    // Botón Eliminar Cuenta - Solo para administradores y policías
                    if (_usuario!.rol != 'ciudadano')
                      Card(
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            child: Icon(
                              Icons.delete_forever,
                              color: Colors.red,
                            ),
                          ),
                          title: Text(
                            'Eliminar Cuenta',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Eliminar permanentemente tu cuenta de la aplicación',
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _navegarAEliminarCuenta,
                        ),
                      ),

                    SizedBox(height: 24),

                    // Información de privacidad - Diferente según el rol
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            _usuario!.rol == 'ciudadano'
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _usuario!.rol == 'ciudadano'
                                  ? Colors.blue.withOpacity(0.3)
                                  : Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _usuario!.rol == 'ciudadano'
                                ? Icons.info_outline
                                : Icons.info_outline,
                            color:
                                _usuario!.rol == 'ciudadano'
                                    ? Colors.blue[700]
                                    : Colors.amber[700],
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _usuario!.rol == 'ciudadano'
                                  ? 'Para opciones adicionales de configuración y gestión de cuenta, ve a la sección "Configuración de Cuenta" en el menú principal.'
                                  : 'Tus datos personales están protegidos. Al eliminar tu cuenta, tus alertas permanecerán en el sistema para fines de registro y seguridad.',
                              style: TextStyle(
                                color:
                                    _usuario!.rol == 'ciudadano'
                                        ? Colors.blue[700]
                                        : Colors.amber[700],
                                fontSize: 14,
                              ),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}

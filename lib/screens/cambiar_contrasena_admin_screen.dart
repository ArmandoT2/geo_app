import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';

class CambiarContrasenaAdminScreen extends StatefulWidget {
  @override
  _CambiarContrasenaAdminScreenState createState() =>
      _CambiarContrasenaAdminScreenState();
}

class _CambiarContrasenaAdminScreenState
    extends State<CambiarContrasenaAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  late User _usuario;
  final _nuevaContrasenaController = TextEditingController();
  final _confirmarContrasenaController = TextEditingController();

  bool _loading = false;
  bool _mostrarContrasena = false;
  bool _mostrarConfirmacion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _usuario = ModalRoute.of(context)!.settings.arguments as User;
  }

  @override
  void dispose() {
    _nuevaContrasenaController.dispose();
    _confirmarContrasenaController.dispose();
    super.dispose();
  }

  Future<void> _cambiarContrasena() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final result = await UserService.cambiarContrasenaAdmin(
        _usuario.id,
        _nuevaContrasenaController.text.trim(),
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result['message']}'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        _mostrarError(result['message']);
      }
    } catch (e) {
      _mostrarError('Error inesperado: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $mensaje'),
        backgroundColor: Colors.red,
      ),
    );
  }

  String? _validarContrasena(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Debe tener al menos una letra mayúscula';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Debe tener al menos un carácter especial';
    }
    return null;
  }

  String? _validarConfirmacion(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirme la contraseña';
    }
    if (value != _nuevaContrasenaController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cambiar Contraseña'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Información del usuario
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usuario a modificar:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _getRolColor(_usuario.rol),
                            child: Icon(
                              _getRolIcon(_usuario.rol),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _usuario.fullName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _usuario.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.only(top: 4),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRolColor(_usuario.rol)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getRolColor(_usuario.rol)
                                          .withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _getRolDisplayName(_usuario.rol),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _getRolColor(_usuario.rol)
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Campos de contraseña
              Text(
                'Nueva contraseña:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),

              TextFormField(
                controller: _nuevaContrasenaController,
                obscureText: !_mostrarContrasena,
                validator: _validarContrasena,
                decoration: InputDecoration(
                  labelText: 'Nueva Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _mostrarContrasena
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _mostrarContrasena = !_mostrarContrasena;
                      });
                    },
                  ),
                ),
              ),

              SizedBox(height: 16),

              TextFormField(
                controller: _confirmarContrasenaController,
                obscureText: !_mostrarConfirmacion,
                validator: _validarConfirmacion,
                decoration: InputDecoration(
                  labelText: 'Confirmar Nueva Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _mostrarConfirmacion
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _mostrarConfirmacion = !_mostrarConfirmacion;
                      });
                    },
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Requisitos de contraseña
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Requisitos de contraseña:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('• Mínimo 8 caracteres'),
                      Text('• Al menos una letra mayúscula'),
                      Text('• Al menos un carácter especial (!@#\$%^&*...)'),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loading ? null : _cambiarContrasena,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Cambiando contraseña...'),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.security),
                          SizedBox(width: 8),
                          Text('Cambiar Contraseña'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Métodos helper para los roles
  Color _getRolColor(String rol) {
    switch (rol.toLowerCase()) {
      case 'administrador':
        return Colors.red;
      case 'policia':
        return Colors.blue;
      case 'ciudadano':
      case 'cliente': // Para compatibilidad con usuarios antiguos
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRolIcon(String rol) {
    switch (rol.toLowerCase()) {
      case 'administrador':
        return Icons.admin_panel_settings;
      case 'policia':
        return Icons.security;
      case 'ciudadano':
      case 'cliente': // Para compatibilidad con usuarios antiguos
        return Icons.person;
      default:
        return Icons.help;
    }
  }

  String _getRolDisplayName(String rol) {
    switch (rol.toLowerCase()) {
      case 'administrador':
        return 'Administrador';
      case 'policia':
        return 'Policía';
      case 'ciudadano':
        return 'Ciudadano';
      case 'cliente': // Para compatibilidad con usuarios antiguos
        return 'Ciudadano';
      default:
        return rol.isNotEmpty ? rol : 'Sin rol';
    }
  }
}

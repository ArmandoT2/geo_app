import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';

class EliminarCuentaScreen extends StatefulWidget {
  final User usuario;

  const EliminarCuentaScreen({super.key, required this.usuario});

  @override
  State<EliminarCuentaScreen> createState() => _EliminarCuentaScreenState();
}

class _EliminarCuentaScreenState extends State<EliminarCuentaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _confirmacionController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _confirmaEliminacion = false;
  bool _ocultarPassword = true;

  @override
  void dispose() {
    _confirmacionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: esError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  Future<void> _eliminarCuenta() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_confirmaEliminacion) {
      _mostrarMensaje(
        'Debe confirmar que desea eliminar su cuenta',
        esError: true,
      );
      return;
    }

    if (_confirmacionController.text.toLowerCase() != 'eliminar') {
      _mostrarMensaje('Debe escribir "eliminar" para confirmar', esError: true);
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      _mostrarMensaje('Debe ingresar su contraseña actual', esError: true);
      return;
    }

    // Confirmación final
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('¡Confirmación Final!'),
              ],
            ),
            content: Text(
              '¿Está absolutamente seguro de eliminar su cuenta?\n\nEsta acción es IRREVERSIBLE.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Sí, Eliminar'),
              ),
            ],
          ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);

    try {
      // Primero eliminar la cuenta en el backend
      bool success = await UserService.eliminarCuentaCiudadano(
        widget.usuario.id,
        _passwordController.text.trim(),
      );

      if (success) {
        // Si el backend se actualizó correctamente, limpiar datos locales
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        _mostrarMensaje('Cuenta eliminada correctamente');

        // Esperar un momento y navegar al login
        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } else {
        _mostrarMensaje(
          'Error al eliminar cuenta en el servidor',
          esError: true,
        );
      }
    } catch (e) {
      _mostrarMensaje('Error: $e', esError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eliminar Cuenta'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Eliminando cuenta...'),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Advertencia
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.warning, size: 48, color: Colors.red),
                            SizedBox(height: 8),
                            Text(
                              '¡ADVERTENCIA!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Esta acción eliminará permanentemente tu cuenta y no se puede deshacer.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.red[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Información del usuario
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cuenta a eliminar:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text('Usuario: ${widget.usuario.username}'),
                              Text('Email: ${widget.usuario.email}'),
                              Text('Nombre: ${widget.usuario.fullName}'),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Consecuencias
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Al eliminar tu cuenta:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text('• Se eliminará tu acceso a la aplicación'),
                              Text('• Se borrará tu información personal'),
                              Text('• Se eliminarán tus contactos guardados'),
                              SizedBox(height: 8),
                              Text(
                                '• Las alertas que hayas creado se conservarán para registros de seguridad',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Confirmación
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Para confirmar, escriba "eliminar":',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 12),

                              TextFormField(
                                controller: _confirmacionController,
                                decoration: InputDecoration(
                                  labelText: 'Escriba "eliminar"',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.keyboard),
                                  hintText: 'eliminar',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Debe escribir "eliminar"';
                                  }
                                  if (value.toLowerCase() != 'eliminar') {
                                    return 'Debe escribir exactamente "eliminar"';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: 16),

                              // Campo de contraseña
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _ocultarPassword,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña actual',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _ocultarPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _ocultarPassword = !_ocultarPassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Debe ingresar su contraseña actual';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: 16),

                              CheckboxListTile(
                                value: _confirmaEliminacion,
                                onChanged: (value) {
                                  setState(
                                    () => _confirmaEliminacion = value ?? false,
                                  );
                                },
                                title: Text(
                                  'Confirmo que entiendo las consecuencias y quiero eliminar mi cuenta',
                                  style: TextStyle(fontSize: 14),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _eliminarCuenta,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_forever),
                              SizedBox(width: 8),
                              Text('ELIMINAR CUENTA PERMANENTEMENTE'),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancelar y mantener mi cuenta'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

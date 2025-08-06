import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController currentPasswordCtrl = TextEditingController();
  final TextEditingController newPasswordCtrl = TextEditingController();
  final TextEditingController confirmPasswordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarEmailUsuario();
  }

  Future<void> _cargarEmailUsuario() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? '';
    emailCtrl.text = email;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La nueva contraseña es requerida';
    }

    List<String> errors = [];

    // Mínimo 8 caracteres
    if (value.length < 8) {
      errors.add('• Mínimo 8 caracteres');
    }

    // Al menos una letra mayúscula
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      errors.add('• Una letra mayúscula');
    }

    // Al menos un carácter especial
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      errors.add('• Un carácter especial');
    }

    if (errors.isNotEmpty) {
      return 'La contraseña debe tener:\n${errors.join('\n')}';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor confirma la nueva contraseña';
    }

    if (value != newPasswordCtrl.text) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  Future<void> changePassword(BuildContext context) async {
    // Validar el formulario
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (emailCtrl.text.trim().isEmpty ||
        currentPasswordCtrl.text.trim().isEmpty ||
        newPasswordCtrl.text.trim().isEmpty ||
        confirmPasswordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener el userId desde SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null || userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: No se pudo obtener el ID del usuario')),
        );
        return;
      }

      // Construir la URL correcta con el userId
      final changePasswordUrl =
          '${AppConfig.usuariosUrl}/$userId/cambiar-password';

      final response = await http
          .put(
            Uri.parse(changePasswordUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': emailCtrl.text.trim(),
              'currentPassword': currentPasswordCtrl.text.trim(),
              'newPassword': newPasswordCtrl.text.trim(),
            }),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '✅ Contraseña actualizada'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Error al cambiar la contraseña'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cambiar Contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                keyboardType: TextInputType.emailAddress,
                readOnly: true,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: currentPasswordCtrl,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La contraseña actual es requerida';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: newPasswordCtrl,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                  helperText:
                      'Mínimo 8 caracteres, una mayúscula y un carácter especial',
                  helperMaxLines: 2,
                  errorMaxLines: 4,
                ),
                obscureText: true,
                validator: _validatePassword,
                onChanged: (value) {
                  // Revalidar el campo de confirmación cuando cambie la nueva contraseña
                  if (confirmPasswordCtrl.text.isNotEmpty) {
                    _formKey.currentState?.validate();
                  }
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordCtrl,
                decoration: InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  prefixIcon: Icon(Icons.lock_reset),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: _validateConfirmPassword,
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => changePassword(context),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Actualizar Contraseña',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

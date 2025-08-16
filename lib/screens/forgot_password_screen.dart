import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController newPasswordCtrl = TextEditingController();
  final TextEditingController confirmPasswordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _showPasswordFields = false;

  // Función para validar formato de email
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  Future<void> resetPassword(BuildContext context) async {
    final email = emailCtrl.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor ingresa tu correo electrónico')),
      );
      return;
    }

    // Validar formato de email
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor ingresa un email válido')),
      );
      return;
    }

    if (_showPasswordFields) {
      // Validar campos de nueva contraseña
      if (newPasswordCtrl.text.trim().isEmpty ||
          confirmPasswordCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Por favor completa todos los campos')),
        );
        return;
      }

      if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Las contraseñas no coinciden')),
        );
        return;
      }

      if (newPasswordCtrl.text.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('La contraseña debe tener al menos 8 caracteres')),
        );
        return;
      }

      if (!RegExp(r'[A-Z]').hasMatch(newPasswordCtrl.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'La contraseña debe tener al menos una letra mayúscula')),
        );
        return;
      }

      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(newPasswordCtrl.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'La contraseña debe tener al menos un carácter especial')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final endpoint = _showPasswordFields
          ? '${AppConfig.apiUrl}/auth/reset-password'
          : '${AppConfig.apiUrl}/auth/forgot-password';

      final body = _showPasswordFields
          ? {
              'email': email,
              'newPassword': newPasswordCtrl.text.trim(),
            }
          : {
              'email': email,
            };

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (_showPasswordFields) {
          // Contraseña cambiada exitosamente
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Contraseña actualizada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          // Email verificado, mostrar campos de nueva contraseña
          setState(() {
            _showPasswordFields = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('✅ Email verificado. Ahora ingresa tu nueva contraseña'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Error al procesar la solicitud'),
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
      appBar: AppBar(
        title: Text('Recuperar Contraseña'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            const SizedBox(height: 20),
            Icon(
              Icons.lock_reset,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 30),
            Text(
              _showPasswordFields
                  ? 'Ingresa tu nueva contraseña'
                  : 'Recuperar Contraseña',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _showPasswordFields
                  ? 'Crea una nueva contraseña segura para tu cuenta'
                  : 'Ingresa tu correo electrónico para recuperar tu contraseña',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),

            // Campo de email
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              enabled: !_showPasswordFields, // Deshabilitar si ya se verificó
              decoration: InputDecoration(
                labelText: 'Correo Electrónico',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
                filled: _showPasswordFields,
                fillColor: _showPasswordFields ? Colors.grey[100] : null,
              ),
            ),

            // Campos de nueva contraseña (solo si el email fue verificado)
            if (_showPasswordFields) ...[
              const SizedBox(height: 20),
              TextField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nueva Contraseña',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                  helperText: 'Mínimo 6 caracteres',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirmar Nueva Contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 30),

            // Botón principal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => resetPassword(context),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _showPasswordFields
                            ? 'Actualizar Contraseña'
                            : 'Verificar Email',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Enlace para volver al login
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
              child: Text('Volver al Login'),
            ),
          ],
        ),
      ),
    );
  }
}

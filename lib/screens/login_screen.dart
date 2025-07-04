import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> loginUser(BuildContext context) async {
    if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Debug: Mostrar URL que se está usando
      print('Intentando conectar a: ${AppConfig.loginUrl}');
      print('Base URL: ${AppConfig.baseUrl}');

      final response = await http
          .post(
            Uri.parse(AppConfig.loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': emailCtrl.text.trim(),
              'password': passwordCtrl.text.trim(),
            }),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      final data = jsonDecode(response.body);
      print('Respuesta backend login: $data');

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();

        // Guardar datos del usuario en SharedPreferences
        await prefs.setString('email', emailCtrl.text.trim());

        final user = data['user'];
        if (user != null) {
          final userId = user['_id'];
          if (userId != null) {
            await prefs.setString('userId', userId);
          }

          final rol = user['rol'];
          if (rol != null) {
            // Migrar usuarios con rol "cliente" a "ciudadano"
            String rolFinal = rol == 'cliente' ? 'ciudadano' : rol;
            await prefs.setString('rol', rolFinal);

            // Si el rol cambió, actualizar en el backend
            if (rol == 'cliente' && userId != null) {
              _migrarRolUsuario(userId);
            }
          }

          // Guardar datos adicionales del usuario
          final username = user['username'];
          if (username != null) {
            await prefs.setString('username', username);
          }

          final fullName = user['fullName'];
          if (fullName != null) {
            await prefs.setString('fullName', fullName);
          }

          final phone = user['phone'];
          if (phone != null) {
            await prefs.setString('phone', phone);
          }

          final address = user['address'];
          if (address != null) {
            await prefs.setString('address', address);
          }

          final genero = user['genero'];
          if (genero != null) {
            await prefs.setString('genero', genero);
          }
        }

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Error de login')),
        );
      }
    } catch (e) {
      print('Error detallado: $e');
      String errorMessage = 'Error de conexión';

      if (e.toString().contains('Connection refused')) {
        errorMessage =
            'No se puede conectar al servidor. Verifica que el backend esté ejecutándose en ${AppConfig.baseUrl}';
      } else if (e.toString().contains('Network is unreachable')) {
        errorMessage = 'Sin conexión a internet';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Tiempo de espera agotado';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), duration: Duration(seconds: 5)),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            shrinkWrap: true,
            children: [
              // LOGO
              Column(
                children: [
                  Image.asset('assets/images/logoApp.jpeg', height: 120),
                  const SizedBox(height: 20),
                  Text(
                    'Bienvenido',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Email y contraseña
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Botón de ingresar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => loginUser(context),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    textStyle: TextStyle(fontSize: 16),
                  ),
                  child:
                      _isLoading
                          ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            'Ingresar',
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ),
              const SizedBox(height: 12),

              // Enlaces de texto
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: Text('¿No tienes cuenta? Regístrate'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pushNamed(context, '/change-password'),
                child: Text('¿Olvidaste tu contraseña?'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para migrar usuarios con rol "cliente" a "ciudadano"
  Future<void> _migrarRolUsuario(String userId) async {
    try {
      await http.put(
        Uri.parse('${AppConfig.usuariosUrl}/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rol': 'ciudadano'}),
      );
      print('Rol migrado de cliente a ciudadano para usuario $userId');
    } catch (e) {
      print('Error al migrar rol: $e');
    }
  }
}

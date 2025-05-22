import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterScreen extends StatelessWidget {
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController fullNameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController rolCtrl = TextEditingController();

  Future<void> registerUser(BuildContext context) async {
    final url = Uri.parse('http://localhost:3000/api/auth/register'); // Usa tu IP local si estás en físico
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': usernameCtrl.text,
        'fullName': fullNameCtrl.text,
        'email': emailCtrl.text,
        'password': passwordCtrl.text,
        'phone': phoneCtrl.text,
        'address': addressCtrl.text,
        'rol': rolCtrl.text,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Usuario creado exitosamente")));
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Error al registrar')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(controller: usernameCtrl, decoration: InputDecoration(labelText: 'Usuario')),
            TextField(controller: fullNameCtrl, decoration: InputDecoration(labelText: 'Nombre completo')),
            TextField(controller: emailCtrl, decoration: InputDecoration(labelText: 'Correo')),
            TextField(controller: passwordCtrl, decoration: InputDecoration(labelText: 'Contraseña'), obscureText: true),
            TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: 'Teléfono')),
            TextField(controller: addressCtrl, decoration: InputDecoration(labelText: 'Dirección')),
             TextField(controller: rolCtrl, decoration: InputDecoration(labelText: 'Rol')),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () => registerUser(context), child: Text('Registrarse')),
          ],
        ),
      ),
    );
  }
}

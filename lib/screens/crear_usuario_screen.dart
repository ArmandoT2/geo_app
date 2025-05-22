import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CrearUsuarioScreen extends StatefulWidget {
  @override
  _CrearUsuarioScreenState createState() => _CrearUsuarioScreenState();
}

class _CrearUsuarioScreenState extends State<CrearUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _loading = false;

  Future<void> _crearUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final url = Uri.parse('http://localhost:3000/usuarios');
    final body = {
      'username': _usernameController.text.trim(),
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'rol': 'policia',
    };

    try {
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body));

      if (response.statusCode == 201) {
        Navigator.pop(context); // Regresar a la pantalla anterior
      } else {
        final error = json.decode(response.body)['message'] ?? 'Error desconocido';
        _mostrarError(error);
      }
    } catch (e) {
      _mostrarError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Crear Usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _campo(_usernameController, 'Username'),
              _campo(_fullNameController, 'Nombre Completo'),
              _campo(_emailController, 'Email', TextInputType.emailAddress),
              _campo(_passwordController, 'Contraseña', TextInputType.text),
              _campo(_phoneController, 'Teléfono', TextInputType.phone),
              _campo(_addressController, 'Dirección'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _crearUsuario,
                child: Text(_loading ? 'Creando...' : 'Crear Usuario'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(TextEditingController controller, String label,
      [TextInputType inputType = TextInputType.text, bool obscureText = false]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        obscureText: obscureText,
        validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_service.dart';

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

  String selectedRol = 'policia';
  String selectedGenero = 'masculino';
  bool _loading = false;

  final List<Map<String, String>> roles = [
    {'value': 'ciudadano', 'label': 'Ciudadano'},
    {'value': 'policia', 'label': 'Policía'},
    {'value': 'administrador', 'label': 'Administrador'},
  ];

  // Función para formatear el número telefónico ecuatoriano
  String _formatPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }

    if (cleanPhone.startsWith('593')) {
      cleanPhone = cleanPhone.substring(3);
    }

    if (cleanPhone.length == 9) {
      return '+593$cleanPhone';
    }

    return phone;
  }

  // Función para validar número telefónico ecuatoriano
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El teléfono es requerido';
    }

    String cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.startsWith('0')) {
      if (cleanPhone.length != 10) {
        return 'El número debe tener 10 dígitos (empezando con 0)';
      }
      String secondDigit = cleanPhone.substring(1, 2);
      if (!['2', '3', '4', '5', '6', '7', '8', '9'].contains(secondDigit)) {
        return 'Número de teléfono ecuatoriano inválido';
      }
    } else if (cleanPhone.length == 9) {
      String firstDigit = cleanPhone.substring(0, 1);
      if (!['2', '3', '4', '5', '6', '7', '8', '9'].contains(firstDigit)) {
        return 'Número de teléfono ecuatoriano inválido';
      }
    } else {
      return 'Ingrese un número válido (10 dígitos con 0, o 9 sin 0)';
    }

    return null;
  }

  Future<void> _crearUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    // Formatear el número de teléfono antes de enviarlo
    String formattedPhone = _formatPhoneNumber(_phoneController.text.trim());

    final userData = {
      'username': _usernameController.text.trim(),
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'phone': formattedPhone,
      'address': _addressController.text.trim(),
      'genero': selectedGenero,
      'rol': selectedRol,
    };

    try {
      final success = await UserService.crearUsuario(userData);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Usuario creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        _mostrarError('Error al crear el usuario');
      }
    } catch (e) {
      _mostrarError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
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

              // Campo especial para teléfono con formato ecuatoriano
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '0987654321 (10 dígitos)',
                    border: OutlineInputBorder(),
                    prefixText: '+593 ',
                    prefixStyle: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                    helperText: 'Ingrese el número con 0 inicial',
                    helperStyle: TextStyle(fontSize: 12),
                  ),
                  validator: _validatePhoneNumber,
                ),
              ),

              _campo(_addressController, 'Dirección'),

              // Dropdown para género
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: selectedGenero,
                  decoration: InputDecoration(
                    labelText: 'Género',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'masculino',
                      child: Text('Masculino'),
                    ),
                    DropdownMenuItem(
                      value: 'femenino',
                      child: Text('Femenino'),
                    ),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedGenero = newValue!;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecciona un género';
                    }
                    return null;
                  },
                ),
              ),

              // Dropdown para rol
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: selectedRol,
                  decoration: InputDecoration(
                    labelText: 'Rol del usuario',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      roles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role['value'],
                          child: Text(role['label']!),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedRol = newValue!;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecciona un rol';
                    }
                    return null;
                  },
                ),
              ),
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

  Widget _campo(
    TextEditingController controller,
    String label, [
    TextInputType inputType = TextInputType.text,
    bool obscureText = false,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        obscureText: obscureText,
        validator:
            (value) =>
                value == null || value.isEmpty ? 'Campo requerido' : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

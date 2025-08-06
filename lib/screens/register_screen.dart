import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController fullNameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final TextEditingController confirmPasswordCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();

  String selectedRol = 'ciudadano'; // Solo ciudadano para registro público
  String selectedGenero = 'masculino'; // Género por defecto
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print(
      'Register Screen iniciado - Género inicial: $selectedGenero',
    ); // Debug
  }

  // Función para formatear el número telefónico ecuatoriano
  String _formatPhoneNumber(String phone) {
    // Remover espacios y caracteres no numéricos
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Si el número empieza con 0, removerlo (formato nacional)
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }

    // Si el número empieza con 593, removerlo (ya está en formato internacional)
    if (cleanPhone.startsWith('593')) {
      cleanPhone = cleanPhone.substring(3);
    }

    // Debe quedar con 9 dígitos (números ecuatorianos sin el 0 inicial)
    if (cleanPhone.length == 9) {
      return '+593$cleanPhone';
    }

    return phone; // Si no cumple el formato, devolver original
  }

  // Función para validar número telefónico ecuatoriano
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El teléfono es requerido';
    }

    String cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');

    // Verificar si empieza con 0 (formato nacional)
    if (cleanPhone.startsWith('0')) {
      if (cleanPhone.length != 10) {
        return 'El número debe tener 10 dígitos (empezando con 0)';
      }
      // Verificar que el segundo dígito sea válido para Ecuador
      String secondDigit = cleanPhone.substring(1, 2);
      if (!['2', '3', '4', '5', '6', '7', '8', '9'].contains(secondDigit)) {
        return 'Número de teléfono ecuatoriano inválido';
      }
    }
    // Si no empieza con 0, debe tener 9 dígitos
    else if (cleanPhone.length == 9) {
      String firstDigit = cleanPhone.substring(0, 1);
      if (!['2', '3', '4', '5', '6', '7', '8', '9'].contains(firstDigit)) {
        return 'Número de teléfono ecuatoriano inválido';
      }
    } else {
      return 'Ingrese un número válido (10 dígitos con 0, o 9 sin 0)';
    }

    return null;
  }

  Future<void> registerUser(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Formatear el número de teléfono antes de enviarlo
      String formattedPhone = _formatPhoneNumber(phoneCtrl.text.trim());

      final response = await http
          .post(
            Uri.parse(AppConfig.registerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': usernameCtrl.text.trim(),
              'fullName': fullNameCtrl.text.trim(),
              'email': emailCtrl.text.trim(),
              'password': passwordCtrl.text.trim(),
              'phone': formattedPhone,
              'address': addressCtrl.text.trim(),
              'genero': selectedGenero,
              'rol': selectedRol,
            }),
          )
          .timeout(Duration(seconds: AppConfig.connectionTimeout));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Usuario creado exitosamente"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Error al registrar'),
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
        title: Text('Registro de Usuario'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Logo o título
              Icon(Icons.person_add, size: 80, color: Colors.blue),
              SizedBox(height: 20),
              Text(
                'Crear Nueva Cuenta',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),

              // Campos del formulario
              TextFormField(
                controller: usernameCtrl,
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El usuario es requerido';
                  }
                  if (value.trim().length < 3) {
                    return 'El usuario debe tener al menos 3 caracteres';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: fullNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre completo es requerido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El correo es requerido';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Ingresa un correo válido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  helperText:
                      'Mínimo 8 caracteres, una mayúscula y un carácter especial',
                  helperMaxLines: 2,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La contraseña es requerida';
                  }
                  if (value.length < 8) {
                    return 'La contraseña debe tener al menos 8 caracteres';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                    return 'La contraseña debe tener al menos una letra mayúscula';
                  }
                  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                    return 'La contraseña debe tener al menos un carácter especial';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Revalidar el campo de confirmación cuando cambie la contraseña
                  if (confirmPasswordCtrl.text.isNotEmpty) {
                    _formKey.currentState?.validate();
                  }
                },
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor confirma la contraseña';
                  }
                  if (value != passwordCtrl.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  hintText: '0987654321 (10 dígitos)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
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
              SizedBox(height: 16),

              TextFormField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La dirección es requerida';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Dropdown para género - NUEVO CAMPO
              DropdownButtonFormField<String>(
                value: selectedGenero,
                decoration: InputDecoration(
                  labelText: 'Género',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline, color: Colors.blue),
                  filled: true,
                  fillColor: Colors.blue.shade50,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'masculino',
                    child: Text('Masculino', style: TextStyle(fontSize: 16)),
                  ),
                  DropdownMenuItem(
                    value: 'femenino',
                    child: Text('Femenino', style: TextStyle(fontSize: 16)),
                  ),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    selectedGenero = newValue!;
                  });
                  print('Género seleccionado: $selectedGenero'); // Debug
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecciona tu género';
                  }
                  return null;
                },
              ),
              SizedBox(height: 30),

              // Información del tipo de usuario (solo lectura)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tipo de usuario: Ciudadano\n(Los roles de administrador y policía son asignados por el administrador)',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),

              // Botón de registro
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => registerUser(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Registrarse',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 16),

              // Link para ir al login
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: Text('¿Ya tienes cuenta? Inicia sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

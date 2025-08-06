import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../widgets/flutter_map_address_picker.dart';

class EditarPerfilScreen extends StatefulWidget {
  final User usuario;

  const EditarPerfilScreen({super.key, required this.usuario});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.usuario.fullName);
    // Mostrar solo los dígitos del teléfono sin +593
    String phoneDisplay = widget.usuario.phone;
    if (phoneDisplay.startsWith('+593')) {
      phoneDisplay = '0' + phoneDisplay.substring(4);
    }
    _phoneController = TextEditingController(text: phoneDisplay);
    _addressController = TextEditingController(text: widget.usuario.address);
  }

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

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Formatear el número de teléfono antes de guardarlo
      String formattedPhone = _formatPhoneNumber(_phoneController.text.trim());

      // Preparar datos para enviar al backend
      Map<String, dynamic> userData = {
        'fullName': _fullNameController.text.trim(),
        'phone': formattedPhone,
        'address': _addressController.text.trim(),
      };

      // Actualizar en el backend
      bool success = await UserService.actualizarDatosCiudadano(
        widget.usuario.id,
        userData,
      );

      if (success) {
        // Si el backend se actualizó correctamente, actualizar SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('fullName', _fullNameController.text.trim());
        await prefs.setString('phone', formattedPhone);
        await prefs.setString('address', _addressController.text.trim());

        _mostrarMensaje('Datos actualizados correctamente');

        // Esperar un momento y luego regresar
        await Future.delayed(Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _mostrarMensaje(
          'Error al actualizar datos en el servidor',
          esError: true,
        );
      }
    } catch (e) {
      _mostrarMensaje('Error al guardar: $e', esError: true);
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
        title: const Text('Editar Perfil'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _guardarCambios,
              child: Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información no editable
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Información de cuenta',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildReadOnlyField(
                              'Usuario',
                              widget.usuario.username,
                            ),
                            _buildReadOnlyField(
                              'Email',
                              widget.usuario.email,
                            ),
                            // Solo mostrar el rol si no es ciudadano
                            if (widget.usuario.rol != 'ciudadano')
                              _buildReadOnlyField('Rol', widget.usuario.rol),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Formulario editable
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Información personal',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _fullNameController,
                              decoration: InputDecoration(
                                labelText: 'Nombre completo',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Por favor ingrese su nombre completo';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
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
                            // Campo de dirección condicional basado en el rol
                            if (widget.usuario.rol == 'ciudadano')
                              FlutterMapAddressPicker(
                                initialAddress: _addressController.text,
                                onAddressSelected: (address) {
                                  _addressController.text = address;
                                },
                              )
                            else
                              TextFormField(
                                controller: _addressController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'Dirección',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.location_on),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _guardarCambios,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Guardando...'),
                                ],
                              )
                            : Text('Actualizar Información'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
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

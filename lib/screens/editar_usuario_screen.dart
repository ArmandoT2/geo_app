import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';

class EditarUsuarioScreen extends StatefulWidget {
  @override
  _EditarUsuarioScreenState createState() => _EditarUsuarioScreenState();
}

class _EditarUsuarioScreenState extends State<EditarUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  late User _usuario;
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _usuario = ModalRoute.of(context)!.settings.arguments as User;
    _fullNameController.text = _usuario.fullName;
    _emailController.text = _usuario.email;
    _phoneController.text = _usuario.phone;
    _addressController.text = _usuario.address;
  }

  Future<void> _editarUsuario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final userData = {
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
    };

    try {
      final success = await UserService.editarUsuario(_usuario.id, userData);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Usuario actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        _mostrarError('Error al actualizar el usuario');
      }
    } catch (e) {
      _mostrarError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar Usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _campo(_fullNameController, 'Nombre Completo'),
              _campo(_emailController, 'Email'),
              _campo(_phoneController, 'Teléfono'),
              _campo(_addressController, 'Dirección'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _editarUsuario,
                child: Text(_loading ? 'Guardando...' : 'Guardar Cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
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

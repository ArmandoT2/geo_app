import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';

class GestionUsuariosScreen extends StatefulWidget {
  @override
  _GestionUsuariosScreenState createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  List<User> _usuarios = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _loading = true);

    try {
      final usuarios = await UserService.getUsuarios();
      setState(() {
        _usuarios = usuarios;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _irCrearUsuario() async {
    await Navigator.pushNamed(context, '/crear-usuario');
    await _cargarUsuarios(); // Recargar al volver
  }

  Future<void> _irEditarUsuario(User usuario) async {
    await Navigator.pushNamed(context, '/editar-usuario', arguments: usuario);
    await _cargarUsuarios(); // Recargar al volver
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gestión de Usuarios')),
      floatingActionButton: FloatingActionButton(
        onPressed: _irCrearUsuario,
        child: Icon(Icons.add),
      ),
      body:
          _loading
              ? Center(child: CircularProgressIndicator())
              : _usuarios.isEmpty
              ? Center(child: Text('No hay usuarios registrados'))
              : ListView.builder(
                itemCount: _usuarios.length,
                itemBuilder: (context, index) {
                  final u = _usuarios[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(u.fullName),
                      subtitle: Text(u.email),
                      trailing: IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _irEditarUsuario(u),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

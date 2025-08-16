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

  Future<void> _irCambiarContrasena(User usuario) async {
    await Navigator.pushNamed(context, '/cambiar-contrasena-admin',
        arguments: usuario);
  }

  Future<void> _eliminarUsuario(User usuario) async {
    // Mostrar diálogo de confirmación
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Eliminar Usuario'),
          content: Text(
            '¿Estás seguro de que deseas eliminar al usuario "${usuario.fullName}"?\n\nEsta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      try {
        final success = await UserService.eliminarUsuario(usuario.id);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Usuario eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          await _cargarUsuarios(); // Recargar la lista
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar usuario'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Métodos helper para los roles
  Color _getRolColor(String rol) {
    switch (rol.toLowerCase()) {
      case 'administrador':
        return Colors.red;
      case 'policia':
        return Colors.blue;
      case 'ciudadano':
      case 'cliente': // Para compatibilidad con usuarios antiguos
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRolIcon(String rol) {
    switch (rol.toLowerCase()) {
      case 'administrador':
        return Icons.admin_panel_settings;
      case 'policia':
        return Icons.security;
      case 'ciudadano':
      case 'cliente': // Para compatibilidad con usuarios antiguos
        return Icons.person;
      default:
        return Icons.help;
    }
  }

  String _getRolDisplayName(String rol) {
    switch (rol.toLowerCase()) {
      case 'administrador':
        return 'Administrador';
      case 'policia':
        return 'Policía';
      case 'ciudadano':
        return 'Ciudadano';
      case 'cliente': // Para compatibilidad con usuarios antiguos
        return 'Ciudadano';
      default:
        return rol.isNotEmpty ? rol : 'Sin rol';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gestión de Usuarios')),
      floatingActionButton: FloatingActionButton(
        onPressed: _irCrearUsuario,
        child: Icon(Icons.add),
      ),
      body: _loading
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
                        leading: CircleAvatar(
                          backgroundColor: _getRolColor(u.rol),
                          child: Icon(
                            _getRolIcon(u.rol),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(u.fullName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.email),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getRolColor(u.rol).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getRolColor(u.rol).withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getRolDisplayName(u.rol),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getRolColor(u.rol).withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _irEditarUsuario(u),
                              tooltip: 'Editar usuario',
                            ),
                            IconButton(
                              icon:
                                  Icon(Icons.lock_reset, color: Colors.orange),
                              onPressed: () => _irCambiarContrasena(u),
                              tooltip: 'Cambiar contraseña',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _eliminarUsuario(u),
                              tooltip: 'Eliminar usuario',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

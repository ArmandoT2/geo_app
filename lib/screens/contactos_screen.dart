import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/contacto_model.dart';
import '../services/contacto_service.dart';
import '../widgets/common_widgets.dart';
import 'contacto_form_screen.dart';

class ContactosScreen extends StatefulWidget {
  const ContactosScreen({Key? key}) : super(key: key);

  @override
  State<ContactosScreen> createState() => _ContactosScreenState();
}

class _ContactosScreenState extends State<ContactosScreen> {
  List<Contacto> _contactos = [];
  bool _cargando = true;
  String _userId = '';
  final ContactoService _contactoService = ContactoService();

  @override
  void initState() {
    super.initState();
    _cargarContactos();
  }

  Future<void> _cargarContactos() async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId') ?? '';

      print('👤 UserId obtenido: $_userId');

      if (_userId.isNotEmpty) {
        print('📞 Cargando contactos para usuario: $_userId');
        final contactos = await _contactoService.obtenerContactos(_userId);
        print('📞 Contactos cargados: ${contactos.length}');

        if (mounted) {
          setState(() {
            _contactos = contactos;
            _cargando = false;
          });
        }
      } else {
        print('❌ UserId está vacío');
        if (mounted) {
          setState(() {
            _cargando = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error al cargar contactos: $e');
      if (mounted) {
        setState(() {
          _cargando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar contactos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _eliminarContacto(Contacto contacto) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Contacto'),
        content: Text(
          '¿Estás seguro de que deseas eliminar a ${contacto.nombreCompleto}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      try {
        final eliminado = await _contactoService.eliminarContacto(contacto.id);

        if (eliminado && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Contacto eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          _cargarContactos(); // Recargar la lista
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al eliminar contacto: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleNotificaciones(Contacto contacto) async {
    try {
      final nuevoEstado = !contacto.notificacionesActivas;
      final actualizado = await _contactoService.toggleNotificaciones(
        contacto.id,
        nuevoEstado,
      );

      if (actualizado && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoEstado
                  ? '✅ Notificaciones activadas para ${contacto.nombre}'
                  : '⏸️ Notificaciones desactivadas para ${contacto.nombre}',
            ),
            backgroundColor: nuevoEstado ? Colors.green : Colors.orange,
          ),
        );
        _cargarContactos(); // Recargar para actualizar el estado
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al actualizar notificaciones: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirFormulario({Contacto? contacto}) async {
    print('📝 Abriendo formulario con usuarioId: $_userId');
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ContactoFormScreen(contacto: contacto, usuarioId: _userId),
      ),
    );

    if (resultado == true) {
      print('✅ Formulario guardado, recargando contactos');
      _cargarContactos(); // Recargar si se guardó un contacto
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Contactos'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Banner informativo para modo desarrollo
          if (AppConfig.useMockData)
            Container(
              width: double.infinity,
              color: Colors.orange[100],
              padding: EdgeInsets.all(8),
              child: Text(
                '⚠️ Modo desarrollo - Usando datos simulados',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange[800]),
              ),
            ),

          // Contenido principal
          Expanded(
            child: _cargando
                ? LoadingWidget(message: 'Cargando contactos...')
                : _contactos.isEmpty
                    ? EmptyStateWidget(
                        title: 'No tienes contactos',
                        subtitle:
                            'Agrega familiares y amigos para notificarles en caso de emergencia',
                        icon: Icons.contacts,
                        onRefresh: _cargarContactos,
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarContactos,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _contactos.length,
                          itemBuilder: (context, index) {
                            final contacto = _contactos[index];
                            return _buildContactoCard(contacto);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Agregar Contacto',
      ),
    );
  }

  Widget _buildContactoCard(Contacto contacto) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: Icon(
                    _getIconoRelacion(contacto.relacion),
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contacto.nombreCompleto,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        contacto.relacion.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'editar':
                        _abrirFormulario(contacto: contacto);
                        break;
                      case 'eliminar':
                        _eliminarContacto(contacto);
                        break;
                      case 'notificaciones':
                        _toggleNotificaciones(contacto);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'notificaciones',
                      child: Row(
                        children: [
                          Icon(
                            contacto.notificacionesActivas
                                ? Icons.notifications_off
                                : Icons.notifications_active,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            contacto.notificacionesActivas
                                ? 'Desactivar notificaciones'
                                : 'Activar notificaciones',
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Eliminar',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildContactoInfo(Icons.phone, contacto.telefono),
            if (contacto.email?.isNotEmpty == true) ...[
              SizedBox(height: 8),
              _buildContactoInfo(Icons.email, contacto.email!),
            ],
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  contacto.notificacionesActivas
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  size: 16,
                  color: contacto.notificacionesActivas
                      ? Colors.green
                      : Colors.grey,
                ),
                SizedBox(width: 4),
                Text(
                  contacto.notificacionesActivas
                      ? 'Notificaciones activas'
                      : 'Notificaciones desactivadas',
                  style: TextStyle(
                    fontSize: 12,
                    color: contacto.notificacionesActivas
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactoInfo(IconData icon, String texto) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconoRelacion(String relacion) {
    switch (relacion.toLowerCase()) {
      case 'familiar':
        return Icons.family_restroom;
      case 'amigo':
        return Icons.people;
      case 'pareja':
        return Icons.favorite;
      case 'emergencia':
        return Icons.emergency;
      case 'trabajo':
        return Icons.work;
      case 'medico':
        return Icons.medical_services;
      default:
        return Icons.person;
    }
  }
}

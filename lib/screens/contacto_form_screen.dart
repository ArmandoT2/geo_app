import 'package:flutter/material.dart';

import '../models/contacto_model.dart';
import '../services/contacto_service.dart';

class ContactoFormScreen extends StatefulWidget {
  final Contacto? contacto;
  final String usuarioId;

  const ContactoFormScreen({Key? key, this.contacto, required this.usuarioId})
    : super(key: key);

  @override
  State<ContactoFormScreen> createState() => _ContactoFormScreenState();
}

class _ContactoFormScreenState extends State<ContactoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();

  TipoRelacion _relacionSeleccionada = TipoRelacion.familiar;
  bool _notificacionesActivas = true;
  bool _guardando = false;

  final ContactoService _contactoService = ContactoService();

  @override
  void initState() {
    super.initState();
    _inicializarFormulario();
  }

  void _inicializarFormulario() {
    if (widget.contacto != null) {
      final contacto = widget.contacto!;
      _nombreController.text = contacto.nombre;
      _apellidoController.text = contacto.apellido;
      _telefonoController.text = contacto.telefono;
      _emailController.text = contacto.email ?? '';
      _relacionSeleccionada = TipoRelacion.fromString(contacto.relacion);
      _notificacionesActivas = contacto.notificacionesActivas;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _guardarContacto() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() {
      _guardando = true;
    });

    try {
      final contacto = Contacto(
        id: widget.contacto?.id ?? '',
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        telefono: _telefonoController.text.trim(),
        email:
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
        relacion: _relacionSeleccionada.name,
        usuarioId: widget.usuarioId,
        notificacionesActivas: _notificacionesActivas,
        fechaCreacion: widget.contacto?.fechaCreacion ?? DateTime.now(),
        fechaActualizacion: widget.contacto != null ? DateTime.now() : null,
      );

      Contacto? resultado;
      if (widget.contacto == null) {
        // Crear nuevo contacto
        resultado = await _contactoService.crearContacto(contacto);
      } else {
        // Actualizar contacto existente
        resultado = await _contactoService.actualizarContacto(contacto);
      }

      if (resultado != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.contacto == null
                  ? '✅ Contacto creado correctamente'
                  : '✅ Contacto actualizado correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Retornar true para indicar que se guardó
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar contacto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.contacto == null ? 'Agregar Contacto' : 'Editar Contacto',
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_guardando)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Información del formulario
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Información del Contacto',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Nombre
                    TextFormField(
                      controller: _nombreController,
                      decoration: InputDecoration(
                        labelText: 'Nombre *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es obligatorio';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),

                    SizedBox(height: 16),

                    // Apellido
                    TextFormField(
                      controller: _apellidoController,
                      decoration: InputDecoration(
                        labelText: 'Apellido *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El apellido es obligatorio';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),

                    SizedBox(height: 16),

                    // Teléfono
                    TextFormField(
                      controller: _telefonoController,
                      decoration: InputDecoration(
                        labelText: 'Teléfono *',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        hintText: 'Ej: +593 99 123 4567',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El teléfono es obligatorio';
                        }
                        if (value.trim().length < 8) {
                          return 'El teléfono debe tener al menos 8 dígitos';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16),

                    // Email (opcional)
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email (opcional)',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                        hintText: 'ejemplo@correo.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value.trim())) {
                            return 'Ingresa un email válido';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Configuración del contacto
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Configuración',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Tipo de relación
                    Text(
                      'Tipo de relación *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<TipoRelacion>(
                      value: _relacionSeleccionada,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(
                          _getIconoRelacion(_relacionSeleccionada),
                        ),
                      ),
                      items:
                          TipoRelacion.values.map((relacion) {
                            return DropdownMenuItem(
                              value: relacion,
                              child: Row(
                                children: [
                                  Icon(_getIconoRelacion(relacion), size: 20),
                                  SizedBox(width: 8),
                                  Text(relacion.displayName),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _relacionSeleccionada = value;
                          });
                        }
                      },
                    ),

                    SizedBox(height: 16),

                    // Notificaciones
                    SwitchListTile(
                      title: Text('Notificaciones de emergencia'),
                      subtitle: Text(
                        _notificacionesActivas
                            ? 'Este contacto recibirá notificaciones cuando emitas una alerta'
                            : 'Este contacto no recibirá notificaciones de emergencia',
                      ),
                      value: _notificacionesActivas,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          _notificacionesActivas = value;
                        });
                      },
                      secondary: Icon(
                        _notificacionesActivas
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color:
                            _notificacionesActivas ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardarContacto,
                icon:
                    _guardando
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Icon(Icons.save),
                label: Text(
                  _guardando
                      ? 'GUARDANDO...'
                      : (widget.contacto == null
                          ? 'CREAR CONTACTO'
                          : 'ACTUALIZAR CONTACTO'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Información adicional
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    SizedBox(height: 8),
                    Text(
                      'Información importante',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Los contactos con notificaciones activas recibirán una alerta automática cuando emitas una emergencia, incluyendo tu ubicación y detalles del incidente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.blue[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconoRelacion(TipoRelacion relacion) {
    switch (relacion) {
      case TipoRelacion.familiar:
        return Icons.family_restroom;
      case TipoRelacion.amigo:
        return Icons.people;
      case TipoRelacion.pareja:
        return Icons.favorite;
      case TipoRelacion.emergencia:
        return Icons.emergency;
      case TipoRelacion.trabajo:
        return Icons.work;
      case TipoRelacion.medico:
        return Icons.medical_services;
      case TipoRelacion.otro:
        return Icons.person;
    }
  }
}

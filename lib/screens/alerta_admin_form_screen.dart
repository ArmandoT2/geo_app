import 'package:flutter/material.dart';

import '../models/alerta_model.dart';
import '../services/alerta_service.dart';

class AlertaAdminFormScreen extends StatefulWidget {
  final Alerta? alerta;

  const AlertaAdminFormScreen({super.key, this.alerta});

  @override
  State<AlertaAdminFormScreen> createState() => _AlertaAdminFormScreenState();
}

class _AlertaAdminFormScreenState extends State<AlertaAdminFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AlertaService _alertaService = AlertaService();

  late TextEditingController _direccionController;
  late TextEditingController _detalleController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  String _status = 'pendiente';
  bool _visible = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _inicializarControladores();
  }

  void _inicializarControladores() {
    if (widget.alerta != null) {
      _direccionController = TextEditingController(
        text: widget.alerta!.direccion,
      );
      _detalleController = TextEditingController(text: widget.alerta!.detalle);
      _latController = TextEditingController(
        text: widget.alerta!.lat?.toString() ?? '',
      );
      _lngController = TextEditingController(
        text: widget.alerta!.lng?.toString() ?? '',
      );
      _status = widget.alerta!.status;
      _visible = widget.alerta!.visible;
    } else {
      _direccionController = TextEditingController();
      _detalleController = TextEditingController();
      _latController = TextEditingController();
      _lngController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _direccionController.dispose();
    _detalleController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final alertaActualizada = Alerta(
        id: widget.alerta?.id ?? '',
        direccion: _direccionController.text,
        usuarioCreador: widget.alerta?.usuarioCreador ?? '',
        fechaHora: widget.alerta?.fechaHora ?? DateTime.now(),
        detalle: _detalleController.text,
        status: _status,
        atendidoPor: widget.alerta?.atendidoPor,
        evidencia: widget.alerta?.evidencia,
        rutaAtencion: widget.alerta?.rutaAtencion,
        lat: double.tryParse(_latController.text),
        lng: double.tryParse(_lngController.text),
        visible: _visible,
      );

      final exito = await _alertaService.actualizarAlerta(
        widget.alerta!.id,
        alertaActualizada,
      );

      if (exito) {
        _mostrarExito('Alerta actualizada correctamente');
        Navigator.pop(context, true);
      } else {
        _mostrarError('Error al actualizar la alerta');
      }
    } catch (e) {
      _mostrarError('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alerta == null ? 'Nueva Alerta' : 'Editar Alerta'),
        actions: [
          if (widget.alerta != null)
            TextButton(
              onPressed: _isLoading ? null : _guardarCambios,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.alerta != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información de la Alerta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('ID: ${widget.alerta!.id}'),
                        Text('Creada por: ${widget.alerta!.usuarioCreador}'),
                        Text('Fecha: ${widget.alerta!.fechaHora}'),
                        if (widget.alerta!.atendidoPor != null)
                          Text('Atendida por: ${widget.alerta!.atendidoPor}'),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],
              TextFormField(
                controller: _direccionController,
                decoration: InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una dirección';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _detalleController,
                maxLines: 3,
                maxLength: 200, // Límite de caracteres
                decoration: InputDecoration(
                  labelText: 'Detalle de la alerta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  hintText:
                      'Describe brevemente la situación (5-50 palabras)...',
                  helperText: 'Entre 5 y 50 palabras, máximo 200 caracteres',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El detalle de la alerta es requerido';
                  }

                  final trimmedValue = value.trim();

                  // Validar caracteres mínimos y máximos
                  if (trimmedValue.length < 10) {
                    return 'Detalle muy corto (mínimo 10 caracteres)';
                  }
                  if (trimmedValue.length > 200) {
                    return 'Detalle muy largo (máximo 200 caracteres)';
                  }

                  // Validar número de palabras
                  final palabras = trimmedValue.split(RegExp(r'\s+'));
                  if (palabras.length < 5) {
                    return 'Detalle muy breve (mínimo 5 palabras)';
                  }
                  if (palabras.length > 50) {
                    return 'Detalle muy extenso (máximo 50 palabras)';
                  }

                  return null;
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: InputDecoration(
                        labelText: 'Latitud',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.my_location),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Latitud inválida';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: InputDecoration(
                        labelText: 'Longitud',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.my_location),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Longitud inválida';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'pendiente',
                    child: Text('Pendiente'),
                  ),
                  DropdownMenuItem(
                    value: 'en_atencion',
                    child: Text('En Atención'),
                  ),
                  DropdownMenuItem(value: 'atendida', child: Text('Atendida')),
                ],
                onChanged: (value) {
                  setState(() => _status = value!);
                },
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('Visible para el ciudadano'),
                subtitle: Text(
                  _visible
                      ? 'La alerta es visible para el ciudadano que la creó'
                      : 'La alerta está oculta del ciudadano (solo para reportes)',
                ),
                value: _visible,
                onChanged: (value) {
                  setState(() => _visible = value);
                },
                secondary: Icon(
                  _visible ? Icons.visibility : Icons.visibility_off,
                ),
              ),
              SizedBox(height: 32),
              if (widget.alerta != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _guardarCambios,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : Text('Actualizar Alerta'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

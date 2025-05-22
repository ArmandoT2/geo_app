import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/alerta_service.dart';
import '../models/alerta_model.dart';

class AlertaFormScreen extends StatefulWidget {
  final String userId;

  AlertaFormScreen({required this.userId});

  @override
  _AlertaFormScreenState createState() => _AlertaFormScreenState();
}

class _AlertaFormScreenState extends State<AlertaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detalleController = TextEditingController();

  String? _direccion;
  bool _cargandoUbicacion = false;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    setState(() => _cargandoUbicacion = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (kIsWeb) {
        // En web solo mostramos coordenadas
        _direccion = 'Lat: ${position.latitude}, Lng: ${position.longitude}';
      } else {
        // En Android tratamos de obtener dirección usando placemark
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        final placemark = placemarks.first;
        _direccion =
            '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}';
      }
    } catch (e) {
      print('Error al obtener ubicación: $e');
      _direccion = 'No se pudo obtener ubicación';
    }

    setState(() => _cargandoUbicacion = false);
  }

  Future<void> _guardarAlerta() async {
    if (!_formKey.currentState!.validate()) return;

    final nuevaAlerta = Alerta(
      id: '', // El backend lo genera
      direccion: _direccion ?? 'Ubicación no disponible',
      usuarioCreador: widget.userId,
      fechaHora: DateTime.now(),
      detalle: _detalleController.text,
      status: 'pendiente',
      atendidoPor: null,
      evidencia: null,
      rutaAtencion: null,
    );

    final respuesta = await AlertaService().crearAlerta(nuevaAlerta);

    if (respuesta) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alerta creada exitosamente')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear alerta')),
      );
    }
  }

  @override
  void dispose() {
    _detalleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Crear Alerta')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _cargandoUbicacion
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _detalleController,
                      decoration: InputDecoration(labelText: 'Detalle de la alerta'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Ingrese un detalle' : null,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Ubicación detectada:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _direccion ?? 'No se pudo obtener ubicación',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    Spacer(),
                    ElevatedButton.icon(
                      onPressed: _guardarAlerta,
                      icon: Icon(Icons.save),
                      label: Text('Guardar Alerta'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

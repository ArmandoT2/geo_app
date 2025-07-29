import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../models/alerta_model.dart';
import '../services/alerta_service.dart';
import '../services/location_service.dart';
import '../widgets/common_widgets.dart';
import 'alerta_tracking_screen.dart';

class AlertaFormScreen extends StatefulWidget {
  final String userId;
  AlertaFormScreen({required this.userId});

  @override
  _AlertaFormScreenState createState() => _AlertaFormScreenState();
}

class _AlertaFormScreenState extends State<AlertaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detalleController = TextEditingController();

  LatLng? _selectedPosition;
  String _direccionActual = 'Obteniendo ubicación...';
  Map<String, String> _direccionDetallada = {};
  bool _cargandoUbicacion = true;
  bool _enviandoAlerta = false;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionActual();
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        await _actualizarDireccion(position);
      } else {
        final defaultPosition = LatLng(-12.0464, -77.0428); // Lima por defecto
        await _actualizarDireccion(defaultPosition);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo obtener la ubicación actual. Usando ubicación por defecto.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      final defaultPosition = LatLng(-12.0464, -77.0428); // Lima por defecto
      await _actualizarDireccion(defaultPosition);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo obtener la ubicación actual. Usando ubicación por defecto.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _actualizarDireccion(LatLng position) async {
    setState(() {
      _selectedPosition = position;
      _direccionActual = 'Obteniendo dirección...';
      _cargandoUbicacion = false;
    });

    try {
      _direccionDetallada =
          await LocationService.getDetailedAddressFromCoordinates(position);
      _direccionActual = _direccionDetallada['direccion_completa'] ??
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    } catch (e) {
      _direccionActual =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      print('Error obteniendo dirección: $e');
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _guardarAlerta() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecciona una ubicación en el mapa'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _enviandoAlerta = true;
    });

    try {
      print('=== CREANDO ALERTA ===');
      final nuevaAlerta = Alerta(
        id: '', // Se asignará en el backend
        direccion: _direccionActual,
        usuarioCreador: widget.userId,
        fechaHora: DateTime.now(),
        detalle: _detalleController.text.trim(),
        status: 'pendiente',
        lat: _selectedPosition!.latitude,
        lng: _selectedPosition!.longitude,
        calle: _direccionDetallada['calle'],
        barrio: _direccionDetallada['barrio'],
        ciudad: _direccionDetallada['ciudad'],
        estado: _direccionDetallada['estado'],
        pais: _direccionDetallada['pais'],
        codigoPostal: _direccionDetallada['codigo_postal'],
      );

      print('Usuario ID: ${widget.userId}');
      print('Detalle: ${_detalleController.text.trim()}');
      print(
          'Ubicación: ${_selectedPosition!.latitude}, ${_selectedPosition!.longitude}');
      print('Dirección: $_direccionActual');

      final alertaCreada = await AlertaService().crearAlerta(nuevaAlerta);
      print('Respuesta del servicio: $alertaCreada');

      if (alertaCreada != null) {
        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✅ Alerta enviada exitosamente\nSerás dirigido al seguimiento',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Esperar un momento antes de navegar para que el usuario vea el mensaje
          await Future.delayed(Duration(milliseconds: 500));

          // Navegar directamente a la pantalla de seguimiento de la alerta
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AlertaTrackingScreen(alerta: alertaCreada),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '❌ Error al enviar la alerta\nPor favor, intenta nuevamente',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'REINTENTAR',
                textColor: Colors.white,
                onPressed: () => _guardarAlerta(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error catch en _guardarAlerta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '❌ Error de conexión\nRevisa tu conexión a internet y vuelve a intentar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'REINTENTAR',
              textColor: Colors.white,
              onPressed: () => _guardarAlerta(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _enviandoAlerta = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crear Alerta de Emergencia'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _cargandoUbicacion
          ? LoadingWidget(message: 'Obteniendo ubicación...')
          : Column(
              children: [
                // Mapa
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    options: MapOptions(
                      center: _selectedPosition,
                      zoom: 16,
                      onTap: (tapPosition, point) {
                        _actualizarDireccion(point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: AppConfig.mapTileUrl,
                        subdomains: AppConfig.mapSubdomains,
                        userAgentPackageName: 'com.example.geo_app',
                        retinaMode: true,
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          if (_selectedPosition != null)
                            Marker(
                              point: _selectedPosition!,
                              builder: (ctx) => const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Formulario con altura fija
                Container(
                  height: 280,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '🚨 Describe la emergencia',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Campo de descripción
                        Container(
                          height: 80,
                          child: TextFormField(
                            controller: _detalleController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Descripción de la emergencia',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.emergency,
                                color: Colors.red,
                              ),
                              hintText: 'Describe brevemente la situación...',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'La descripción es requerida';
                              }
                              if (value.trim().length < 10) {
                                return 'Mínimo 10 caracteres';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Info de ubicación
                        if (_selectedPosition != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Ubicación: $_direccionActual',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Botón de envío - ESTE ES EL BOTÓN QUE FALTABA
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _enviandoAlerta ? null : _guardarAlerta,
                            icon: _enviandoAlerta
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.emergency,
                                    color: Colors.white,
                                  ),
                            label: Text(
                              _enviandoAlerta
                                  ? 'ENVIANDO...'
                                  : '🚨 ENVIAR ALERTA',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        Text(
                          '💡 Toca en el mapa para ajustar la ubicación precisa',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _detalleController.dispose();
    super.dispose();
  }
}

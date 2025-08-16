import 'dart:async';

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

  // Variables para el timer de cancelación
  bool _mostrarCancelacion = false;
  Timer? _timerCancelacion;
  int _segundosRestantes = 30;
  Alerta? _alertaCreada;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionActual();
  }

  @override
  void dispose() {
    _timerCancelacion?.cancel();
    _detalleController.dispose();
    super.dispose();
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
    if (!mounted) return;

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
    // Validar formulario
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠️ Por favor completa todos los campos requeridos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.location_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '📍 Selecciona una ubicación en el mapa',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!mounted) return;
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
        if (mounted) {
          setState(() {
            _alertaCreada = alertaCreada;
            _mostrarCancelacion = true;
            _enviandoAlerta = false;
          });

          // Iniciar el timer de cancelación
          _iniciarTimerCancelacion();
        }

        // Mostrar mensaje de éxito con opción de cancelación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✅ Alerta enviada exitosamente\nTienes 30 segundos para cancelar si es necesario',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
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
      if (mounted && !_mostrarCancelacion) {
        setState(() {
          _enviandoAlerta = false;
        });
      }
    }
  }

  void _iniciarTimerCancelacion() {
    _segundosRestantes = 30;
    _timerCancelacion = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _segundosRestantes--;
        });

        if (_segundosRestantes <= 0) {
          _finalizarPeriodoCancelacion();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _finalizarPeriodoCancelacion() {
    _timerCancelacion?.cancel();
    if (mounted) {
      setState(() {
        _mostrarCancelacion = false;
      });

      // Navegar al seguimiento de la alerta
      if (_alertaCreada != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AlertaTrackingScreen(alerta: _alertaCreada!),
          ),
        );
      }
    }
  }

  Future<void> _cancelarAlerta() async {
    if (_alertaCreada == null) {
      print('❌ Error: _alertaCreada es null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: No hay alerta para cancelar'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    print('🚫 Iniciando cancelación de alerta: ${_alertaCreada!.id}');

    // Mostrar diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Cancelar Alerta'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas cancelar esta alerta de emergencia?\n\n'
          'Esta acción no se puede deshacer y los servicios de emergencia no serán notificados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No, mantener alerta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Sí, cancelar alerta'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      bool dialogoAbierto = false;
      try {
        print('✅ Usuario confirmó cancelación');

        // Mostrar indicador de carga
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              dialogoAbierto = true;
              return AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Cancelando alerta...'),
                  ],
                ),
              );
            },
          );
        }

        print('📡 Llamando al servicio de cancelación...');
        // Llamar al servicio para cancelar la alerta
        final exito = await AlertaService().cancelarAlerta(_alertaCreada!.id);

        // Cerrar el diálogo de carga si está abierto
        if (mounted && dialogoAbierto && Navigator.canPop(context)) {
          Navigator.pop(context);
          dialogoAbierto = false;
        }

        // Cancelar el timer
        _timerCancelacion?.cancel();

        if (mounted) {
          if (exito) {
            print('✅ Alerta cancelada exitosamente');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Alerta cancelada exitosamente'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // Regresar a la pantalla anterior
            Navigator.pop(context);
          } else {
            print('❌ Error: La respuesta del servidor fue false');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error al cancelar la alerta. Verifica tu conexión a internet e intenta nuevamente.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'REINTENTAR',
                  textColor: Colors.white,
                  onPressed: () => _cancelarAlerta(),
                ),
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Excepción en _cancelarAlerta: $e');
        print('❌ Tipo de error: ${e.runtimeType}');

        // Cerrar el diálogo de carga si está abierto
        if (mounted && dialogoAbierto && Navigator.canPop(context)) {
          Navigator.pop(context);
          dialogoAbierto = false;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin conexión al servidor. Verifica que el backend esté ejecutándose.\n\nError: $e',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'REINTENTAR',
                textColor: Colors.white,
                onPressed: () => _cancelarAlerta(),
              ),
            ),
          );
        }
      }
    } else {
      print('❌ Usuario canceló la confirmación');
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
          : _mostrarCancelacion
              ? _buildPantallaCancelacion()
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

                    // Formulario con altura dinámica
                    Container(
                      constraints: BoxConstraints(
                        minHeight: 280,
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
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
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
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
                                height: 100,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _detalleController,
                                        maxLines: 3,
                                        maxLength: 200, // Límite de caracteres
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Descripción de la emergencia *',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(
                                            Icons.emergency,
                                            color: Colors.red,
                                          ),
                                          hintText:
                                              'Ej: Accidente vehicular con heridos, Incendio en edificio, Robo en progreso...',
                                          helperText:
                                              '💡 Describe qué está pasando (5-50 palabras, máx. 200 caracteres)',
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return '⚠️ Por favor describe la emergencia';
                                          }

                                          final trimmedValue = value.trim();

                                          // Validar caracteres mínimos y máximos
                                          if (trimmedValue.length < 10) {
                                            return '📝 Descripción muy corta (mínimo 10 caracteres)';
                                          }
                                          if (trimmedValue.length > 200) {
                                            return '📝 Descripción muy larga (máximo 200 caracteres)';
                                          }

                                          // Validar número de palabras
                                          final palabras = trimmedValue
                                              .split(RegExp(r'\s+'));
                                          if (palabras.length < 5) {
                                            return '💬 Descripción muy breve (mínimo 5 palabras)';
                                          }
                                          if (palabras.length > 50) {
                                            return '💬 Descripción muy extensa (máximo 50 palabras)';
                                          }

                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
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

                              // Botón de envío
                              SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _enviandoAlerta ? null : _guardarAlerta,
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
                    ),
                  ],
                ),
    );
  }

  Widget _buildPantallaCancelacion() {
    return Container(
      color: Colors.red[50],
      child: Column(
        children: [
          // Header con información del estado
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.red[700],
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  '✅ Alerta Enviada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Los servicios de emergencia han sido notificados',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Timer de cancelación
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.timer,
                          color: Colors.orange[700],
                          size: 40,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Opción de Cancelación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Puedes cancelar esta alerta si fue enviada por error o ya no requieres asistencia',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),

                        // Contador circular
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                value: _segundosRestantes / 30,
                                strokeWidth: 6,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _segundosRestantes > 10
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  '$_segundosRestantes',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: _segundosRestantes > 10
                                        ? Colors.orange[700]
                                        : Colors.red[700],
                                  ),
                                ),
                                Text(
                                  'segundos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Información de la alerta
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue[700], size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Detalles de la Alerta',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                _detalleController.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      color: Colors.red, size: 16),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _direccionActual,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _alertaCreada == null ? null : _cancelarAlerta,
                          icon: Icon(Icons.cancel, color: Colors.white),
                          label: Text(
                            'CANCELAR ALERTA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _alertaCreada == null
                                ? Colors.grey
                                : Colors.red[600],
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _finalizarPeriodoCancelacion,
                          icon: Icon(Icons.track_changes, color: Colors.white),
                          label: Text(
                            'IR AL SEGUIMIENTO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Si no realizas ninguna acción, serás dirigido automáticamente al seguimiento cuando termine el tiempo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
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
}

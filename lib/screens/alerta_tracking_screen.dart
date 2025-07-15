import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';

import '../config/app_config.dart';
import '../models/alerta_model.dart';
import '../services/alerta_service.dart';

class AlertaTrackingScreen extends StatefulWidget {
  final Alerta alerta;

  AlertaTrackingScreen({required this.alerta});

  @override
  _AlertaTrackingScreenState createState() => _AlertaTrackingScreenState();
}

class _AlertaTrackingScreenState extends State<AlertaTrackingScreen> {
  late Alerta _alertaActual;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  // Variables para la ruta real
  List<LatLng> _puntosRuta = [];
  bool _cargandoRuta = false;
  double _distanciaRuta = 0.0;
  double _tiempoEstimado = 0.0;
  LatLng? _ubicacionPolicia;
  LatLng? _ubicacionAlerta;

  // Variable para almacenar información del policía
  Map<String, dynamic>? _infoPoliciaAsignado;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _alertaActual = widget.alerta;
    _inicializarUbicaciones();
    _iniciarRefreshAutomatico();

    // Obtener información del policía si está asignado
    if (_alertaActual.atendidoPor != null &&
        _alertaActual.atendidoPor!.isNotEmpty) {
      _obtenerInfoPolicia(_alertaActual.atendidoPor!);
    }
  }

  void _inicializarUbicaciones() {
    // Ubicación de la alerta (destino)
    _ubicacionAlerta = LatLng(
      _alertaActual.lat ?? -12.0464,
      _alertaActual.lng ?? -77.0428,
    );

    // Si hay información de ruta, obtener ubicación del policía
    if (_alertaActual.rutaAtencion != null) {
      _ubicacionPolicia = LatLng(
        _alertaActual.rutaAtencion!.origenLat,
        _alertaActual.rutaAtencion!.origenLng,
      );

      // Generar ruta real entre las ubicaciones
      _generarRutaReal();
    }

    // Obtener información del policía asignado si existe
    if (_alertaActual.atendidoPor != null) {
      _obtenerInfoPolicia(_alertaActual.atendidoPor!);
    }
  }

  void _iniciarRefreshAutomatico() {
    // Refresh cada 10 segundos si la alerta no está finalizada
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (_alertaActual.status != 'atendida' &&
          _alertaActual.status != 'cancelada') {
        _actualizarAlerta();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _actualizarAlerta() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Aquí asumimos que tienes un método para obtener una alerta específica
      // Si no existe, puedes implementarlo en AlertaService
      final alertasActualizadas = await AlertaService()
          .obtenerAlertasPorUsuario(_alertaActual.usuarioCreador);
      final alertaActualizada = alertasActualizadas.firstWhere(
        (a) => a.id == _alertaActual.id,
        orElse: () => _alertaActual,
      );

      if (mounted) {
        setState(() {
          _alertaActual = alertaActualizada;
        });

        // Si hay nueva información de ruta, actualizar
        if (alertaActualizada.rutaAtencion != null &&
            (_ubicacionPolicia == null ||
                _ubicacionPolicia!.latitude !=
                    alertaActualizada.rutaAtencion!.origenLat ||
                _ubicacionPolicia!.longitude !=
                    alertaActualizada.rutaAtencion!.origenLng)) {
          _inicializarUbicaciones();
        }

        // Si se asignó un nuevo policía, obtener su información
        if (alertaActualizada.atendidoPor != null &&
            alertaActualizada.atendidoPor != _alertaActual.atendidoPor) {
          _obtenerInfoPolicia(alertaActualizada.atendidoPor!);
        }
      }
    } catch (e) {
      print('Error actualizando alerta: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  int obtenerPasoEstado(String status) {
    switch (status) {
      case 'pendiente':
        return 1;
      case 'asignado':
        return 2;
      case 'en camino':
        return 3;
      case 'atendida':
        return 4;
      case 'cancelada':
        return 0;
      default:
        return 0;
    }
  }

  String obtenerTextoEstado(String status) {
    switch (status) {
      case 'pendiente':
        return 'Alerta registrada';
      case 'asignado':
        return 'Policía asignado';
      case 'en camino':
        return 'En camino';
      case 'atendida':
        return 'Alerta atendida';
      case 'cancelada':
        return 'Cancelada';
      default:
        return 'Estado desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seguimiento de Alerta'),
        actions: [
          if (_isRefreshing)
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
            )
          else
            IconButton(icon: Icon(Icons.refresh), onPressed: _actualizarAlerta),
        ],
      ),
      body: Column(
        children: [
          // Información compacta de la alerta - REDUCIDA
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Indicador de progreso más compacto
                StepProgressIndicator(
                  totalSteps: 4,
                  currentStep: obtenerPasoEstado(_alertaActual.status),
                  selectedColor: Colors.green,
                  unselectedColor: Colors.grey[300]!,
                  size: 6,
                ),
                SizedBox(height: 12),

                // Card compacta con información esencial
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Estado actual
                        Row(
                          children: [
                            Icon(
                              _getIconoEstado(_alertaActual.status),
                              color: _getColorEstado(_alertaActual.status),
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                obtenerTextoEstado(_alertaActual.status),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _getColorEstado(_alertaActual.status),
                                ),
                              ),
                            ),
                            if (_alertaActual.rutaAtencion != null) ...[
                              Icon(
                                Icons.route,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${_calcularDistancia().toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 6),

                        // Detalle de la alerta
                        Text(
                          _alertaActual.detalle,
                          style: TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),

                        // Ubicación compacta
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.blue[700],
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _alertaActual.direccion,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        if (_alertaActual.atendidoPor != null) ...[
                          SizedBox(height: 4),
                          _buildInfoPoliciaCompacta(),
                        ],

                        if (_cargandoRuta) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Calculando ruta...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Mapa - AHORA OCUPA MÁS ESPACIO
          Expanded(
            flex: 4, // Dar más peso al mapa
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center:
                    _ubicacionAlerta ??
                    LatLng(
                      _alertaActual.lat ?? -12.0464,
                      _alertaActual.lng ?? -77.0428,
                    ),
                zoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConfig.mapTileUrl,
                  subdomains: AppConfig.mapSubdomains,
                  userAgentPackageName: 'com.example.geo_app',
                  retinaMode: true,
                  maxZoom: 19,
                ),

                // Línea de ruta real por calles
                if (_puntosRuta.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _puntosRuta,
                        strokeWidth: 5.0,
                        color: Colors.green[700]!,
                        borderStrokeWidth: 2.0,
                        borderColor: Colors.white,
                      ),
                    ],
                  )
                // Fallback: línea recta si no hay ruta real
                else if (_alertaActual.rutaAtencion != null &&
                    _ubicacionPolicia != null &&
                    _ubicacionAlerta != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_ubicacionPolicia!, _ubicacionAlerta!],
                        color: Colors.orange,
                        strokeWidth: 4.0,
                        isDotted: true,
                      ),
                    ],
                  ),

                MarkerLayer(
                  markers: [
                    // Marcador de la alerta (destino)
                    if (_ubicacionAlerta != null)
                      Marker(
                        point: _ubicacionAlerta!,
                        builder:
                            (ctx) => Container(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.emergency,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'TU UBICACIÓN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ),

                    // Marcador del policía si existe ruta
                    if (_ubicacionPolicia != null)
                      Marker(
                        point: _ubicacionPolicia!,
                        builder:
                            (ctx) => Container(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.local_police,
                                    color: Colors.blue,
                                    size: 40,
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'POLICÍA',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Botones de acción
          if (_alertaActual.rutaAtencion != null)
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _cargandoRuta || !mounted
                              ? null
                              : () {
                                if (mounted) _ajustarVistaDelMapa();
                              },
                      icon: Icon(Icons.center_focus_strong),
                      label: Text('Centrar Ruta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _cargandoRuta || !mounted
                              ? null
                              : () {
                                if (mounted) _actualizarAlerta();
                              },
                      icon: Icon(Icons.refresh),
                      label: Text('Actualizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconoEstado(String status) {
    switch (status) {
      case 'pendiente':
        return Icons.schedule;
      case 'asignado':
        return Icons.person_add;
      case 'en camino':
        return Icons.directions_car;
      case 'atendida':
        return Icons.check_circle;
      case 'cancelada':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getColorEstado(String status) {
    switch (status) {
      case 'pendiente':
        return Colors.orange;
      case 'asignado':
        return Colors.blue;
      case 'en camino':
        return Colors.purple;
      case 'atendida':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _generarRutaReal() {
    if (_ubicacionPolicia == null || _ubicacionAlerta == null) return;
    if (!mounted) return;

    setState(() {
      _cargandoRuta = true;
    });

    // Obtener ruta real por calles
    _obtenerRutaReal();
  }

  Future<void> _obtenerRutaReal() async {
    if (_ubicacionPolicia == null || _ubicacionAlerta == null) return;
    if (!mounted) return;

    // Intentar primero con OSRM (más confiable y gratuito)
    bool rutaObtenida = await _obtenerRutaOSRM();

    if (!rutaObtenida && mounted) {
      // Si OSRM falla, intentar con OpenRouteService
      rutaObtenida = await _obtenerRutaOpenRouteService();
    }

    if (!rutaObtenida && mounted) {
      // Si ambos fallan, usar ruta directa
      _usarRutaDirecta();
    }
  }

  Future<bool> _obtenerRutaOSRM() async {
    if (!mounted) return false;

    try {
      // OSRM Demo Server (gratuito)
      final String url =
          'http://router.project-osrm.org/route/v1/driving/' +
          '${_ubicacionPolicia!.longitude},${_ubicacionPolicia!.latitude};' +
          '${_ubicacionAlerta!.longitude},${_ubicacionAlerta!.latitude}' +
          '?overview=full&geometries=geojson';

      final response = await http
          .get(Uri.parse(url))
          .timeout(Duration(seconds: 10));

      if (!mounted) return false;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;

          if (mounted) {
            setState(() {
              _puntosRuta =
                  coordinates.map<LatLng>((coord) {
                    return LatLng(coord[1].toDouble(), coord[0].toDouble());
                  }).toList();

              _distanciaRuta =
                  (route['distance'] / 1000).toDouble(); // Convertir a km
              _tiempoEstimado =
                  (route['duration'] / 60).toDouble(); // Convertir a minutos
              _cargandoRuta = false;
            });

            _ajustarVistaDelMapa();
          }

          return true;
        }
      }
    } catch (e) {
      print('Error con OSRM: $e');
    }

    return false;
  }

  Future<bool> _obtenerRutaOpenRouteService() async {
    if (!mounted) return false;

    try {
      // Usando OpenRouteService API (backup)
      final String url =
          'https://api.openrouteservice.org/v2/directions/driving-car';

      final Map<String, dynamic> requestBody = {
        'coordinates': [
          [_ubicacionPolicia!.longitude, _ubicacionPolicia!.latitude],
          [_ubicacionAlerta!.longitude, _ubicacionAlerta!.latitude],
        ],
        'format': 'geojson',
        'geometry_simplify': false,
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: 10));

      if (!mounted) return false;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['features'] != null && data['features'].isNotEmpty) {
          final coordinates =
              data['features'][0]['geometry']['coordinates'] as List;
          final properties = data['features'][0]['properties']['segments'][0];

          if (mounted) {
            setState(() {
              _puntosRuta =
                  coordinates.map<LatLng>((coord) {
                    return LatLng(coord[1].toDouble(), coord[0].toDouble());
                  }).toList();

              _distanciaRuta =
                  (properties['distance'] / 1000).toDouble(); // Convertir a km
              _tiempoEstimado =
                  (properties['duration'] / 60)
                      .toDouble(); // Convertir a minutos
              _cargandoRuta = false;
            });

            _ajustarVistaDelMapa();
          }

          return true;
        }
      }
    } catch (e) {
      print('Error con OpenRouteService: $e');
    }

    return false;
  }

  void _usarRutaDirecta() {
    if (!mounted) return;

    // Fallback: línea recta si no se puede obtener la ruta real
    setState(() {
      _puntosRuta = [_ubicacionPolicia!, _ubicacionAlerta!];
      final Distance distance = Distance();
      _distanciaRuta = distance.as(
        LengthUnit.Kilometer,
        _ubicacionPolicia!,
        _ubicacionAlerta!,
      );
      _tiempoEstimado =
          _distanciaRuta * 2; // Estimación aproximada: 2 min por km
      _cargandoRuta = false;
    });

    _ajustarVistaDelMapa();
  }

  void _ajustarVistaDelMapa() {
    if (!mounted || _ubicacionPolicia == null || _ubicacionAlerta == null)
      return;

    // Si tenemos puntos de ruta, calcular bounds para todos
    List<LatLng> puntosParaBounds =
        _puntosRuta.isNotEmpty
            ? _puntosRuta
            : [_ubicacionPolicia!, _ubicacionAlerta!];

    if (puntosParaBounds.length < 2) return;

    // Encontrar los límites de todos los puntos
    double minLat = puntosParaBounds
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLat = puntosParaBounds
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    double minLng = puntosParaBounds
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLng = puntosParaBounds
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

    // Agregar margen
    double margenLat = (maxLat - minLat) * 0.1;
    double margenLng = (maxLng - minLng) * 0.1;

    // Centrar el mapa en el punto medio
    final centro = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    // Calcular zoom apropiado basado en la distancia
    double deltaLat = maxLat - minLat + margenLat;
    double deltaLng = maxLng - minLng + margenLng;
    double zoom = 15 - (deltaLat + deltaLng) * 30; // Fórmula aproximada
    zoom = zoom.clamp(10.0, 18.0); // Limitar zoom entre 10 y 18

    try {
      _mapController.move(centro, zoom);
    } catch (e) {
      // Ignorar errores si el mapa no está listo
      print('Error al mover el mapa: $e');
    }
  }

  Future<String> _obtenerDireccionDesdeCoordenadas() async {
    if (_alertaActual.lat == null || _alertaActual.lng == null) {
      return 'Ubicación no disponible';
    }

    try {
      // Usar servicio de geocodificación reversa para obtener dirección legible
      final String url =
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json'
          '&lat=${_alertaActual.lat}'
          '&lon=${_alertaActual.lng}'
          '&addressdetails=1'
          '&accept-language=es';

      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'GeoApp/1.0'})
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];

        if (address != null) {
          List<String> partesDireccion = [];

          // Construir dirección legible
          if (address['road'] != null) {
            partesDireccion.add(address['road']);
          }
          if (address['neighbourhood'] != null) {
            partesDireccion.add(address['neighbourhood']);
          } else if (address['suburb'] != null) {
            partesDireccion.add(address['suburb']);
          }
          if (address['city'] != null) {
            partesDireccion.add(address['city']);
          } else if (address['town'] != null) {
            partesDireccion.add(address['town']);
          } else if (address['village'] != null) {
            partesDireccion.add(address['village']);
          }

          if (partesDireccion.isNotEmpty) {
            return partesDireccion.join(', ');
          }
        }

        // Si hay display_name pero no pudimos construir la dirección detallada
        if (data['display_name'] != null) {
          String displayName = data['display_name'];
          // Tomar solo las primeras 3 partes para que no sea muy largo
          List<String> partes = displayName.split(',').take(3).toList();
          return partes.join(',').trim();
        }
      }
    } catch (e) {
      print('Error al obtener dirección desde coordenadas: $e');
    }

    return 'Ubicación: ${_alertaActual.lat!.toStringAsFixed(4)}, ${_alertaActual.lng!.toStringAsFixed(4)}';
  }

  Widget _buildInfoPolicia() {
    if (_alertaActual.atendidoPor == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(12),
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
              Icon(Icons.local_police, color: Colors.blue[700], size: 18),
              SizedBox(width: 6),
              Text(
                'Policía Asignado',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          if (_infoPoliciaAsignado != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_infoPoliciaAsignado!['fullName'] ?? 'Nombre no disponible'}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'POLICÍA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: Colors.blue[700], size: 24),
                ),
              ],
            ),
          ] else ...[
            // Mientras se carga la información
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Obteniendo información del policía...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDireccionDetallada() {
    List<String> partesDireccion = [];

    // Agregar calle si existe
    if (_alertaActual.calle != null && _alertaActual.calle!.isNotEmpty) {
      partesDireccion.add(_alertaActual.calle!);
    }

    // Agregar barrio si existe
    if (_alertaActual.barrio != null && _alertaActual.barrio!.isNotEmpty) {
      partesDireccion.add(_alertaActual.barrio!);
    }

    // Agregar ciudad si existe
    if (_alertaActual.ciudad != null && _alertaActual.ciudad!.isNotEmpty) {
      partesDireccion.add(_alertaActual.ciudad!);
    }

    // Si tenemos información detallada, usarla
    if (partesDireccion.isNotEmpty) {
      return Text(
        partesDireccion.join(', '),
        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
      );
    }

    // Si no hay información detallada pero tenemos dirección general que no son coordenadas
    if (_alertaActual.direccion.isNotEmpty &&
        !_alertaActual.direccion.contains('lat') &&
        !RegExp(
          r'^-?\d+\.?\d*,-?\d+\.?\d*$',
        ).hasMatch(_alertaActual.direccion.trim())) {
      return Text(
        _alertaActual.direccion,
        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
      );
    }

    // Usar FutureBuilder para obtener dirección desde coordenadas
    return FutureBuilder<String>(
      future: _obtenerDireccionDesdeCoordenadas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Obteniendo ubicación...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          );
        }

        if (snapshot.hasData) {
          return Text(
            snapshot.data!,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          );
        }

        // Fallback final
        return Text(
          'Ubicación por determinar',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }

  double _calcularDistancia() {
    // Si tenemos la distancia real de la ruta, usarla
    if (_distanciaRuta > 0.0) {
      return _distanciaRuta;
    }

    // Fallback: distancia directa
    if (_ubicacionPolicia == null || _ubicacionAlerta == null) return 0.0;

    final Distance distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      _ubicacionPolicia!,
      _ubicacionAlerta!,
    );
  }

  Future<void> _obtenerInfoPolicia(String policiaId) async {
    if (policiaId.isEmpty) return;

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/usuarios/$policiaId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _infoPoliciaAsignado = data;
          });
        }
      }
    } catch (e) {
      print('Error obteniendo información del policía: $e');
    }
  }

  Widget _buildInfoPoliciaCompacta() {
    if (_infoPoliciaAsignado == null) return SizedBox();

    return Row(
      children: [
        Icon(Icons.local_police, color: Colors.green[700], size: 14),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            'Policía: ${_infoPoliciaAsignado!['fullName'] ?? 'No disponible'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_tiempoEstimado > 0) ...[
          Icon(Icons.access_time, size: 12, color: Colors.blue[600]),
          SizedBox(width: 2),
          Text(
            '${_tiempoEstimado.toStringAsFixed(0)}min',
            style: TextStyle(fontSize: 11, color: Colors.blue[600]),
          ),
        ],
      ],
    );
  }
}

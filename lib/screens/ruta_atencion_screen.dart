import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/alerta_model.dart';
import '../services/alerta_service.dart';
import '../services/location_service.dart';
import '../widgets/common_widgets.dart';

class RutaAtencionScreen extends StatefulWidget {
  final Alerta alerta;

  const RutaAtencionScreen({Key? key, required this.alerta}) : super(key: key);

  @override
  State<RutaAtencionScreen> createState() => _RutaAtencionScreenState();
}

class _RutaAtencionScreenState extends State<RutaAtencionScreen> {
  LatLng? _ubicacionPolicia; // Punto de partida
  LatLng? _ubicacionAlerta; // Destino
  List<LatLng> _puntosRuta = []; // Puntos de la ruta trazada por calles
  bool _cargandoUbicacion = true;
  bool _cargandoRuta = false;
  bool _actualizandoEstado = false;
  String _estadoActual = '';
  double _distanciaRuta = 0.0; // Distancia real de la ruta
  double _tiempoEstimado = 0.0; // Tiempo estimado en minutos
  File? _archivoSeleccionado;
  Uint8List? _archivoWebBytes;
  String? _nombreArchivoWeb;
  String? _urlSubida;

  final String cloudName = 'ddkoq06ti';
  final String uploadPreset = 'unsigned';

  final MapController _mapController = MapController();

  // Variable para almacenar información del usuario creador
  Map<String, dynamic>? _infoUsuarioCreador;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.alerta.status;

    // Debug: Imprimir información de la alerta en RutaAtencionScreen
    print('=== DEBUG RUTA ATENCION SCREEN ===');
    print('Alerta ID: ${widget.alerta.id}');
    print('Dirección (campo original): "${widget.alerta.direccion}"');
    print('Dirección completa (getter): "${widget.alerta.direccionCompleta}"');
    print('Campos individuales:');
    print('  * Calle: "${widget.alerta.calle ?? 'null'}"');
    print('  * Barrio: "${widget.alerta.barrio ?? 'null'}"');
    print('  * Ciudad: "${widget.alerta.ciudad ?? 'null'}"');
    print('  * Estado: "${widget.alerta.estado ?? 'null'}"');
    print('  * País: "${widget.alerta.pais ?? 'null'}"');
    print('  * Código Postal: "${widget.alerta.codigoPostal ?? 'null'}"');
    print('==============================');

    _inicializarUbicaciones();
    _obtenerInfoUsuarioCreador();
  }

  @override
  void dispose() {
    // Limpiar recursos antes de desmontar el widget
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _inicializarUbicaciones() async {
    try {
      // Obtener ubicación actual de la policía
      final ubicacionActual = await LocationService.getCurrentLocation();

      // Ubicación de la alerta (destino)
      final destinoAlerta = LatLng(
        widget.alerta.lat ?? -12.0464,
        widget.alerta.lng ?? -77.0428,
      );

      if (mounted) {
        setState(() {
          _ubicacionPolicia = ubicacionActual ?? LatLng(-12.0464, -77.0428);
          _ubicacionAlerta = destinoAlerta;
          _cargandoUbicacion = false;
        });

        // Generar ruta entre ambos puntos
        _generarRuta();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ubicacionPolicia = LatLng(-12.0464, -77.0428); // Lima por defecto
          _ubicacionAlerta = LatLng(
            widget.alerta.lat ?? -12.0464,
            widget.alerta.lng ?? -77.0428,
          );
          _cargandoUbicacion = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo obtener la ubicación actual'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _generarRuta() {
    if (_ubicacionPolicia == null || _ubicacionAlerta == null) return;

    // Obtener ruta real por calles usando OpenRouteService
    _obtenerRutaReal();
  }

  Future<void> _obtenerRutaReal() async {
    if (_ubicacionPolicia == null || _ubicacionAlerta == null) return;
    if (!mounted) return;

    setState(() {
      _cargandoRuta = true;
    });

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

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Ruta calculada por calles'),
                backgroundColor: Colors.green,
              ),
            );
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

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Ruta calculada por calles'),
                backgroundColor: Colors.green,
              ),
            );
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Usando ruta directa. No se pudo obtener ruta por calles.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
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

  Future<void> _actualizarEstadoAlerta(String nuevoEstado) async {
    if (!mounted) return;
    setState(() => _actualizandoEstado = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final policiaId = prefs.getString('userId') ?? '';
      String? evidenciaUrl;

      if (nuevoEstado == 'atendida') {
        // Permitir completar sin evidencia, pero mostrar mensaje informativo
        if ((!kIsWeb && _archivoSeleccionado == null) ||
            (kIsWeb &&
                (_archivoWebBytes == null || _nombreArchivoWeb == null))) {
          // Solo mostrar mensaje informativo, no bloquear la operación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ℹ️ Completando alerta sin evidencia. Podrás cargarla después.',
              ),
              backgroundColor: Colors.blue,
            ),
          );
        } else {
          // Si hay archivo, intentar subirlo
          evidenciaUrl = await subirArchivoACloudinary();

          if (evidenciaUrl == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Error al subir evidencia a Cloudinary'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _actualizandoEstado = false);
            return;
          }
        }
      }

      final actualizado = await AlertaService().actualizarEstado(
        widget.alerta.id,
        nuevoEstado,
        policiaId,
        origenLat: _ubicacionPolicia?.latitude,
        origenLng: _ubicacionPolicia?.longitude,
        destinoLat: _ubicacionAlerta?.latitude,
        destinoLng: _ubicacionAlerta?.longitude,
        evidenciaUrl: evidenciaUrl,
      );

      if (!mounted) return;

      if (actualizado) {
        setState(() => _estadoActual = nuevoEstado);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Estado actualizado a: $nuevoEstado'),
            backgroundColor: Colors.green,
          ),
        );
        if (nuevoEstado == 'atendida') Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al actualizar el estado'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizandoEstado = false);
    }
  }

  Future<void> seleccionarArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(withData: true);

    if (resultado != null) {
      if (kIsWeb) {
        _archivoWebBytes = resultado.files.first.bytes;
        _nombreArchivoWeb = resultado.files.first.name;
      } else {
        _archivoSeleccionado = File(resultado.files.first.path!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Archivo seleccionado: ${resultado.files.first.name}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<String?> subirArchivoACloudinary() async {
    final cloudName = 'ddkoq06ti';
    final uploadPreset = 'unsigned';

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload',
    );
    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = uploadPreset;

    if (!kIsWeb && _archivoSeleccionado != null) {
      request.files.add(
        await http.MultipartFile.fromPath('file', _archivoSeleccionado!.path),
      );
    } else if (kIsWeb &&
        _archivoWebBytes != null &&
        _nombreArchivoWeb != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _archivoWebBytes!,
          filename: _nombreArchivoWeb!,
          contentType: MediaType('application', 'octet-stream'),
        ),
      );
    } else {
      return null;
    }

    final response = await request.send();
    final res = await http.Response.fromStream(response);

    if (response.statusCode == 200) {
      final data = json.decode(res.body);
      return data['secure_url'];
    } else {
      print('❌ Cloudinary error: ${res.body}');
      return null;
    }
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

  Widget _buildDireccionDetallada() {
    String direccionCompleta = _construirDireccionMejor();

    return Text(
      direccionCompleta,
      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _construirDireccionMejor() {
    // Priorizar el campo 'direccion' si contiene información completa
    if (widget.alerta.direccion.isNotEmpty &&
        widget.alerta.direccion.contains(',') &&
        !widget.alerta.direccion.contains('Lat:')) {
      return widget.alerta.direccion;
    }

    // Si no, construir desde campos individuales
    List<String> partes = [];

    if (widget.alerta.calle != null && widget.alerta.calle!.isNotEmpty) {
      partes.add(widget.alerta.calle!);
    }
    if (widget.alerta.barrio != null && widget.alerta.barrio!.isNotEmpty) {
      partes.add(widget.alerta.barrio!);
    }
    if (widget.alerta.ciudad != null && widget.alerta.ciudad!.isNotEmpty) {
      partes.add(widget.alerta.ciudad!);
    }
    if (widget.alerta.estado != null && widget.alerta.estado!.isNotEmpty) {
      partes.add(widget.alerta.estado!);
    }
    if (widget.alerta.pais != null && widget.alerta.pais!.isNotEmpty) {
      partes.add(widget.alerta.pais!);
    }

    if (partes.length >= 2) {
      return partes.join(', ');
    }

    // Fallback al campo direccion original
    if (widget.alerta.direccion.isNotEmpty) {
      return widget.alerta.direccion;
    }

    // Último recurso: coordenadas
    if (widget.alerta.lat != null && widget.alerta.lng != null) {
      return 'Lat: ${widget.alerta.lat!.toStringAsFixed(4)}, Lng: ${widget.alerta.lng!.toStringAsFixed(4)}';
    }

    return 'Ubicación no disponible';
  }

  Future<void> _obtenerInfoUsuarioCreador() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.baseUrl}/usuarios/${widget.alerta.usuarioCreador}',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _infoUsuarioCreador = data;
          });
        }
      }
    } catch (e) {
      print('Error obteniendo información del usuario creador: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Atender Alerta'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _inicializarUbicaciones,
          ),
        ],
      ),
      body:
          _cargandoUbicacion
              ? LoadingWidget(message: 'Obteniendo ubicaciones...')
              : Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      4,
                                    ), // Reducido de 8 a 4
                                    color: Colors.red[50],
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '🚨 Emergencia Activa',
                                          style: TextStyle(
                                            fontSize: 16, // Reducido de 18 a 16
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red[700],
                                          ),
                                        ),
                                        SizedBox(
                                          height: 2,
                                        ), // Reducido de 4 a 2
                                        Text(
                                          widget.alerta.detalle,
                                          style: TextStyle(
                                            fontSize: 14,
                                          ), // Reducido de 16 a 14
                                        ),
                                        SizedBox(
                                          height: 4,
                                        ), // Reducido de 6 a 4
                                        // Información combinada del incidente y ciudadano
                                        Container(
                                          padding: EdgeInsets.all(
                                            6,
                                          ), // Reducido de 8 a 6
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Ubicación del incidente
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on,
                                                    color: Colors.blue[700],
                                                    size:
                                                        14, // Reducido de 16 a 14
                                                  ),
                                                  SizedBox(
                                                    width: 3,
                                                  ), // Reducido de 4 a 3
                                                  Text(
                                                    'Ubicación del Incidente:',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue[700],
                                                      fontSize:
                                                          12, // Reducido de 14 a 12
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: 2,
                                              ), // Reducido de 3 a 2
                                              _buildDireccionDetallada(),

                                              SizedBox(
                                                height: 4,
                                              ), // Reducido de 6 a 4
                                              // Información del ciudadano
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.person,
                                                    color: Colors.green[700],
                                                    size:
                                                        14, // Reducido de 16 a 14
                                                  ),
                                                  SizedBox(
                                                    width: 3,
                                                  ), // Reducido de 4 a 3
                                                  Text(
                                                    'Ciudadano que Reportó:',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green[700],
                                                      fontSize:
                                                          12, // Reducido de 14 a 12
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: 2,
                                              ), // Reducido de 3 a 2
                                              if (_infoUsuarioCreador !=
                                                  null) ...[
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            '${_infoUsuarioCreador!['fullName'] ?? 'Nombre no disponible'}',
                                                            style: TextStyle(
                                                              fontSize:
                                                                  12, // Reducido de 14 a 12
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors
                                                                      .grey[800],
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            height: 1,
                                                          ), // Reducido de 2 a 1
                                                          Container(
                                                            padding: EdgeInsets.symmetric(
                                                              horizontal:
                                                                  4, // Reducido de 6 a 4
                                                              vertical:
                                                                  1, // Reducido de 2 a 1
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors
                                                                      .green[100],
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              'CIUDADANO',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    Colors
                                                                        .green[700],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      width:
                                                          28, // Reducido de 32 a 28
                                                      height:
                                                          28, // Reducido de 32 a 28
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.green[100],
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.person,
                                                        color:
                                                            Colors.green[700],
                                                        size:
                                                            16, // Reducido de 18 a 16
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ] else ...[
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Obteniendo información...',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        SizedBox(
                                          height: 2,
                                        ), // Reducido de 4 a 2
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Chip(
                                              label: Text(
                                                _estadoActual.toUpperCase(),
                                              ),
                                              backgroundColor: _getColorEstado(
                                                _estadoActual,
                                              ),
                                              labelStyle: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Distancia: ${_calcularDistancia().toStringAsFixed(2)} km',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                                if (_tiempoEstimado > 0)
                                                  Text(
                                                    'Tiempo est.: ${_tiempoEstimado.toStringAsFixed(0)} min',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.blue[600],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 4), // Reducido de 6 a 4
                                  Container(
                                    height:
                                        constraints.maxHeight *
                                        0.75, // Aumentado a 75% para un mapa más grande
                                    child: FlutterMap(
                                      mapController: _mapController,
                                      options: MapOptions(
                                        center:
                                            _ubicacionPolicia ??
                                            LatLng(-12.0464, -77.0428),
                                        zoom: 13,
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate: AppConfig.mapTileUrl,
                                          subdomains: AppConfig.mapSubdomains,
                                          userAgentPackageName:
                                              'com.example.geo_app',
                                          retinaMode: true,
                                          maxZoom: 19,
                                        ),
                                        if (_puntosRuta.isNotEmpty)
                                          PolylineLayer(
                                            polylines: [
                                              Polyline(
                                                points: _puntosRuta,
                                                strokeWidth: 5.0,
                                                color: Colors.blue[700]!,
                                                borderStrokeWidth: 2.0,
                                                borderColor: Colors.white,
                                              ),
                                            ],
                                          ),
                                        MarkerLayer(
                                          markers: [
                                            if (_ubicacionPolicia != null)
                                              Marker(
                                                point: _ubicacionPolicia!,
                                                builder:
                                                    (ctx) => Column(
                                                      children: [
                                                        Icon(
                                                          Icons.local_police,
                                                          color: Colors.blue,
                                                          size: 40,
                                                        ),
                                                        Container(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 4,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            'POLICÍA',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                              ),
                                            if (_ubicacionAlerta != null)
                                              Marker(
                                                point: _ubicacionAlerta!,
                                                builder:
                                                    (ctx) => Column(
                                                      children: [
                                                        Icon(
                                                          Icons.emergency,
                                                          color: Colors.red,
                                                          size: 40,
                                                        ),
                                                        Container(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 4,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            'EMERGENCIA',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
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
                          ),
                          Container(
                            padding: EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              // ← Solución agregada
                              child: Column(
                                mainAxisSize:
                                    MainAxisSize
                                        .min, // ← evita expansión innecesaria
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              _actualizandoEstado ||
                                                      _cargandoRuta ||
                                                      !mounted
                                                  ? null
                                                  : () {
                                                    if (mounted)
                                                      _ajustarVistaDelMapa();
                                                  },
                                          icon: Icon(
                                            Icons.center_focus_strong,
                                            size: 16,
                                          ),
                                          label: Text('Centrar'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[600],
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 8,
                                            ),
                                            minimumSize: Size(0, 36),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              _actualizandoEstado ||
                                                      _cargandoRuta ||
                                                      !mounted
                                                  ? null
                                                  : () {
                                                    if (mounted)
                                                      _obtenerRutaReal();
                                                  },
                                          icon: Icon(Icons.route, size: 16),
                                          label: Text('Ruta'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green[600],
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 8,
                                            ),
                                            minimumSize: Size(0, 36),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              _actualizandoEstado ||
                                                      _cargandoRuta ||
                                                      !mounted
                                                  ? null
                                                  : () {
                                                    if (mounted)
                                                      _inicializarUbicaciones();
                                                  },
                                          icon: Icon(
                                            Icons.my_location,
                                            size: 16,
                                          ),
                                          label: Text('GPS'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[600],
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 8,
                                            ),
                                            minimumSize: Size(0, 36),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  _buildBotonesEstado(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_cargandoRuta)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Calculando ruta por calles...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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

  Widget _buildBotonesEstado() {
    List<Map<String, dynamic>> estados = [
      {
        'estado': 'asignado',
        'texto': 'Aceptar Alerta',
        'color': Colors.orange,
        'icon': Icons.assignment_turned_in,
      },
      {
        'estado': 'en camino',
        'texto': 'Ir al Lugar',
        'color': Colors.blue,
        'icon': Icons.directions_car,
      },
      {
        'estado': 'atendida',
        'texto': 'Completar Atención',
        'color': Colors.green,
        'icon': Icons.check_circle,
      },
    ];

    String estadoActual = _estadoActual;
    Map<String, dynamic>? siguienteEstado;

    for (var estado in estados) {
      if ((estadoActual == 'pendiente' && estado['estado'] == 'asignado') ||
          (estadoActual == 'asignado' && estado['estado'] == 'en camino') ||
          (estadoActual == 'en camino' && estado['estado'] == 'atendida')) {
        siguienteEstado = estado;
        break;
      }
    }

    if (siguienteEstado == null) {
      return Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                SizedBox(width: 8),
                Text(
                  'Alerta Completada',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          // Botón para cargar evidencia después de completar la alerta
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: seleccionarArchivo,
              icon: Icon(Icons.attach_file),
              label: Text('Cargar Evidencia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Botón principal de acción
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed:
                _actualizandoEstado || !mounted
                    ? null
                    : () {
                      if (mounted)
                        _actualizarEstadoAlerta(siguienteEstado!['estado']);
                    },
            icon:
                _actualizandoEstado
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : Icon(siguienteEstado['icon']),
            label: Text(
              _actualizandoEstado
                  ? 'ACTUALIZANDO...'
                  : siguienteEstado['texto'],
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: siguienteEstado['color'],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.red;
      case 'asignado':
        return Colors.orange;
      case 'en camino':
        return Colors.blue;
      case 'atendida':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

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

/*
 * PANTALLA: ATENDER ALERTA (RutaAtencionScreen)
 * 
 * FUNCIONALIDAD PRINCIPAL:
 * - Centrado automático del mapa en la ubicación del incidente al cargar la pantalla
 * - Soporte para re-entrada: cuando el gendarme vuelve a entrar a una alerta "en camino"
 * 
 * COMPORTAMIENTO ESPERADO:
 * 1. Al abrir la pantalla, el mapa se centra automáticamente en las coordenadas del incidente
 * 2. El nivel de zoom por defecto (16.0) muestra claramente el punto y el contexto
 * 3. NO se requiere ninguna acción manual del usuario para ver la ubicación del incidente
 * 4. El botón "Centrar" está disponible como backup para centrado manual
 * 
 * SOLUCIONES IMPLEMENTADAS:
 * - Centrado inmediato en initState()
 * - Centrado en onMapReady() con secuencia de recentrados
 * - Centrado adicional post-inicialización para casos de re-entrada
 * - Centrado final de seguridad después de 2 segundos
 * - Botón de centrado manual mejorado (color naranja, más visible)
 */

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

  final String cloudName = 'ddkoq06ti';
  final String uploadPreset = 'unsigned';

  final MapController _mapController = MapController();

  // Variable para almacenar información del usuario creador
  Map<String, dynamic>? _infoUsuarioCreador;

  // Controlador para el campo de detalles de atención
  final TextEditingController _detallesAtencionController =
      TextEditingController();
  bool _detallesValidos = false;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.alerta.status;

    // Debug: Imprimir información de la alerta en RutaAtencionScreen
    print('=== DEBUG RUTA ATENCION SCREEN ===');
    print('Alerta ID: ${widget.alerta.id}');
    print('Estado actual: ${widget.alerta.status}');
    print('Dirección (campo original): "${widget.alerta.direccion}"');
    print('Dirección completa (getter): "${widget.alerta.direccionCompleta}"');
    print('Coordenadas: lat=${widget.alerta.lat}, lng=${widget.alerta.lng}');

    // **DEBUG ESPECÍFICO PARA "EN CAMINO"**
    if (widget.alerta.status == 'en camino') {
      print(
          '🚚 ESTADO "EN CAMINO" DETECTADO - Aplicando lógica especial de centrado');
      print(
          '   -> Se aplicarán delays adicionales para evitar interferencia de rutas');
      print('   -> Se forzará re-centrado después de generar rutas');
    }

    print('==============================');

    // **CRÍTICO: Establecer coordenadas de la alerta INMEDIATAMENTE**
    if (widget.alerta.lat != null && widget.alerta.lng != null) {
      _ubicacionAlerta = LatLng(widget.alerta.lat!, widget.alerta.lng!);
      print(
          '🎯 Coordenadas de alerta establecidas inmediatamente: ${_ubicacionAlerta}');
    }

    // Inicializar después de que el widget esté completamente construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inicializarUbicaciones();
        _obtenerInfoUsuarioCreador();
      }
    });
  }

  @override
  void dispose() {
    // Limpiar recursos antes de desmontar el widget
    _mapController.dispose();
    _detallesAtencionController.dispose();
    super.dispose();
  }

  Future<void> _inicializarUbicaciones() async {
    try {
      // Configurar ubicación de la alerta primero (sin esperar)
      final destinoAlerta = LatLng(
        widget.alerta.lat ?? -12.0464,
        widget.alerta.lng ?? -77.0428,
      );

      // Establecer estado inicial inmediatamente
      if (mounted) {
        setState(() {
          _ubicacionAlerta = destinoAlerta;
          _cargandoUbicacion = false;
        });
      }

      // Obtener ubicación de policía en background (con timeout)
      LocationService.getCurrentLocation()
          .timeout(
        Duration(seconds: 3),
        onTimeout: () => null,
      )
          .then((ubicacionActual) {
        if (mounted) {
          setState(() {
            _ubicacionPolicia = ubicacionActual ?? LatLng(-12.0464, -77.0428);
          });

          // Generar ruta solo si obtuvimos la ubicación
          _generarRuta();
        }
      }).catchError((e) {
        print('Error obteniendo ubicación de policía: $e');
        if (mounted) {
          setState(() {
            _ubicacionPolicia = LatLng(-12.0464, -77.0428);
          });
        }
      });

      // Debug: Verificar coordenadas
      print('🔍 Coordenadas establecidas:');
      print('  Alerta: ${widget.alerta.lat}, ${widget.alerta.lng}');
      print(
          '  _ubicacionAlerta: ${_ubicacionAlerta?.latitude}, ${_ubicacionAlerta?.longitude}');

      // Centrar el mapa en el punto del incidente después de un pequeño delay
      if (widget.alerta.lat != null && widget.alerta.lng != null) {
        Future.delayed(Duration(milliseconds: 200), () {
          if (mounted) {
            final puntoIncidente =
                LatLng(widget.alerta.lat!, widget.alerta.lng!);
            _mapController.move(puntoIncidente, 16.0);
            print(
                '🎯 Mapa centrado en incidente: ${widget.alerta.lat}, ${widget.alerta.lng}');
          }
        });
      }
    } catch (e) {
      print('Error inicializando ubicaciones: $e');
      if (mounted) {
        setState(() {
          _ubicacionPolicia = LatLng(-12.0464, -77.0428);
          _ubicacionAlerta = LatLng(
            widget.alerta.lat ?? -12.0464,
            widget.alerta.lng ?? -77.0428,
          );
          _cargandoUbicacion = false;
        });
      }
    }
  }

  void _generarRuta() {
    if (_ubicacionPolicia == null || _ubicacionAlerta == null) return;

    // Generar ruta en background sin bloquear la UI
    _obtenerRutaReal().catchError((e) {
      print('Error generando ruta: $e');
      if (mounted) {
        setState(() {
          _cargandoRuta = false;
        });
      }
    });
  }

  Future<void> _obtenerRutaReal() async {
    if (_ubicacionPolicia == null || _ubicacionAlerta == null || !mounted)
      return;

    setState(() {
      _cargandoRuta = true;
    });

    try {
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
    } catch (e) {
      print('Error obteniendo ruta: $e');
      if (mounted) {
        _usarRutaDirecta();
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargandoRuta = false;
        });
      }
    }
  }

  Future<bool> _obtenerRutaOSRM() async {
    if (!mounted) return false;

    try {
      // OSRM Demo Server (gratuito)
      final String url = 'http://router.project-osrm.org/route/v1/driving/' +
          '${_ubicacionPolicia!.longitude},${_ubicacionPolicia!.latitude};' +
          '${_ubicacionAlerta!.longitude},${_ubicacionAlerta!.latitude}' +
          '?overview=full&geometries=geojson';

      final response =
          await http.get(Uri.parse(url)).timeout(Duration(seconds: 5));

      if (!mounted) return false;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;

          if (mounted) {
            setState(() {
              _puntosRuta = coordinates.map<LatLng>((coord) {
                return LatLng(coord[1].toDouble(), coord[0].toDouble());
              }).toList();

              _distanciaRuta =
                  (route['distance'] / 1000).toDouble(); // Convertir a km
              _tiempoEstimado =
                  (route['duration'] / 60).toDouble(); // Convertir a minutos
              _cargandoRuta = false;
            });

            // **IMPLEMENTACIÓN DEL REQUERIMIENTO: Centrado automático en incidente**
            // NO llamar a _ajustarVistaDelMapa() automáticamente aquí
            // para mantener el centro en el incidente, que es el comportamiento deseado

            // **FIX ADICIONAL PARA "EN CAMINO": Re-centrar después de obtener ruta OSRM**
            if (_estadoActual == 'en camino') {
              Future.delayed(Duration(milliseconds: 500), () {
                if (mounted &&
                    widget.alerta.lat != null &&
                    widget.alerta.lng != null) {
                  final puntoIncidente =
                      LatLng(widget.alerta.lat!, widget.alerta.lng!);
                  _mapController.move(puntoIncidente, 16.0);
                  print(
                      '🎯 Re-centrado post-ruta OSRM para estado "en camino"');
                }
              });
            }

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
              _puntosRuta = coordinates.map<LatLng>((coord) {
                return LatLng(coord[1].toDouble(), coord[0].toDouble());
              }).toList();

              _distanciaRuta =
                  (properties['distance'] / 1000).toDouble(); // Convertir a km
              _tiempoEstimado = (properties['duration'] / 60)
                  .toDouble(); // Convertir a minutos
              _cargandoRuta = false;
            });

            // **IMPLEMENTACIÓN DEL REQUERIMIENTO: Centrado automático en incidente**
            // NO llamar a _ajustarVistaDelMapa() automáticamente aquí
            // para mantener el centro en el incidente, que es el comportamiento deseado

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

    // **IMPLEMENTACIÓN DEL REQUERIMIENTO: Centrado automático en incidente**
    // NO llamar a _ajustarVistaDelMapa() automáticamente aquí
    // para mantener el centro en el incidente, que es el comportamiento deseado

    // **FIX ADICIONAL PARA "EN CAMINO": Re-centrar después de ruta directa**
    if (_estadoActual == 'en camino') {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && widget.alerta.lat != null && widget.alerta.lng != null) {
          final puntoIncidente = LatLng(widget.alerta.lat!, widget.alerta.lng!);
          _mapController.move(puntoIncidente, 16.0);
          print('🎯 Re-centrado post-ruta directa para estado "en camino"');
        }
      });
    }

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

  // Función específica para centrar el mapa en el punto del incidente (llamada por botón)
  void _centrarEnIncidente() {
    if (!mounted || _ubicacionAlerta == null) return;

    // Verificar que tenemos coordenadas válidas
    if (widget.alerta.lat == null || widget.alerta.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Esta alerta no tiene coordenadas GPS disponibles'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Coordenadas exactas del incidente
      final puntoIncidente = LatLng(widget.alerta.lat!, widget.alerta.lng!);

      print(
          '🎯 Centrando mapa manualmente en incidente (botón): Lat: ${widget.alerta.lat}, Lng: ${widget.alerta.lng}');

      // Proceso de centrado secuencial para asegurar precisión
      Future.microtask(() {
        // Primer movimiento: zoom moderado para preparar
        _mapController.move(puntoIncidente, 14.0);

        // Segundo movimiento después de un pequeño delay: zoom final con centrado preciso
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            // Centrado final con zoom cómodo que muestre bien el punto
            _mapController.move(
              puntoIncidente,
              15.5, // Zoom más bajo para ver mejor el punto y el contexto
            );

            // Forzar otro centrado después de un momento para asegurar precisión
            Future.delayed(Duration(milliseconds: 400), () {
              if (mounted) {
                _mapController.move(puntoIncidente, 15.5);
              }
            });
          }
        });
      });

      // Comentado: No mostrar mensaje de confirmación después del centrado
      /*
      Future.delayed(Duration(milliseconds: 800), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.gps_fixed, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🎯 Mapa centrado exactamente en el incidente\n'
                      'Coordenadas: ${widget.alerta.lat!.toStringAsFixed(6)}, ${widget.alerta.lng!.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[600],
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
      */
    } catch (e) {
      print('Error al centrar en el incidente: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al centrar el mapa'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Nueva función optimizada para centrar el mapa cuando está listo
  void _centrarMapaInicial() async {
    print('🗺️ Mapa listo - iniciando centrado optimizado en el incidente');
    print('📍 Estado de la alerta: ${_estadoActual}');

    if (!mounted || widget.alerta.lat == null || widget.alerta.lng == null) {
      print('❌ No se puede centrar: coordenadas no disponibles');
      return;
    }

    final puntoIncidente = LatLng(widget.alerta.lat!, widget.alerta.lng!);
    print(
        '🎯 Centrando automáticamente en incidente: ${puntoIncidente.latitude}, ${puntoIncidente.longitude}');

    try {
      // **SOLUCIÓN PARA RE-ENTRADA: Centrado inmediato y múltiple**
      // Centrado inmediato sin delay (especialmente importante para re-entrada)
      _mapController.move(puntoIncidente, 16.0);
      print('🚀 Centrado inmediato aplicado');

      // Secuencia de recentrados más agresiva para re-entrada
      final secuenciaCentrado = [
        {'delay': 50, 'zoom': 16.0}, // Muy rápido
        {'delay': 150, 'zoom': 15.8}, // Ligero zoom out
        {'delay': 300, 'zoom': 16.0}, // Zoom de vuelta
        {'delay': 500, 'zoom': 16.0}, // Confirmación
        {'delay': 800, 'zoom': 16.0}, // Asegurar
        {'delay': 1200, 'zoom': 16.0}, // Final
      ];

      for (var config in secuenciaCentrado) {
        Future.delayed(Duration(milliseconds: config['delay'] as int), () {
          if (mounted) {
            _mapController.move(puntoIncidente, config['zoom'] as double);
            print(
                '🔄 Recentrado en incidente - delay ${config['delay']}ms, zoom ${config['zoom']}');
          }
        });
      }

      // Mostrar mensaje de confirmación específico según el estado
      String mensaje = _estadoActual == 'en camino'
          ? '🎯 Regresando al incidente - Mapa centrado automáticamente'
          : '🎯 Mapa centrado automáticamente en el incidente';

      Future.delayed(Duration(milliseconds: 1400), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.gps_fixed, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mensaje,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: _estadoActual == 'en camino'
                  ? Colors.green[600]
                  : Colors.blue[600],
              duration: Duration(seconds: 2),
            ),
          );
        }
      });

      print(
          '✅ Secuencia de centrado automático en incidente iniciada (estado: $_estadoActual)');
    } catch (e) {
      print('❌ Error en centrado automático inicial: $e');
    }
  }

  // Función combinada que obtiene la ubicación GPS y calcula la ruta automáticamente
  Future<void> _obtenerRutaConGPS() async {
    if (!mounted) return;

    setState(() {
      _cargandoRuta = true;
    });

    try {
      // Primero obtener la ubicación actual (GPS)
      final ubicacionActual = await LocationService.getCurrentLocation();

      if (ubicacionActual != null && mounted) {
        setState(() {
          _ubicacionPolicia = ubicacionActual;
        });

        // Mostrar mensaje de confirmación de GPS
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.gps_fixed, color: Colors.white),
                SizedBox(width: 8),
                Text('📍 Ubicación GPS actualizada'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );

        // Luego calcular la ruta automáticamente
        await _obtenerRutaReal();
      } else {
        if (mounted) {
          setState(() {
            _cargandoRuta = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ No se pudo obtener la ubicación GPS'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error obteniendo ubicación GPS: $e');
      if (mounted) {
        setState(() {
          _cargandoRuta = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al obtener ubicación GPS'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
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
                '✅ Alerta completada sin evidencia. La evidencia es opcional.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Si hay archivo, intentar subirlo
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📤 Subiendo evidencia a Cloudinary...',
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );

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
          } else {
            // Éxito al subir evidencia
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Evidencia subida exitosamente'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
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
        detallesAtencion: nuevoEstado == 'atendida'
            ? _detallesAtencionController.text.trim()
            : null,
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
    try {
      final resultado = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.any,
        allowMultiple: false,
      );

      if (resultado != null && resultado.files.isNotEmpty) {
        final file = resultado.files.first;

        // Validar tamaño del archivo (max 10MB)
        if (file.size > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ El archivo es muy grande. Máximo 10MB.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          if (kIsWeb) {
            _archivoWebBytes = file.bytes;
            _nombreArchivoWeb = file.name;
          } else {
            _archivoSeleccionado = File(file.path!);
            _nombreArchivoWeb = file.name;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Archivo seleccionado: ${file.name} (${(file.size / 1024 / 1024).toStringAsFixed(1)} MB)',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al seleccionar archivo: $e'),
          backgroundColor: Colors.red,
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
      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/usuarios/${widget.alerta.usuarioCreador}',
        ),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));

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
      ),
      body: _cargandoUbicacion
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
                                                    fontWeight: FontWeight.bold,
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
                                                    fontWeight: FontWeight.bold,
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
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey[800],
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: 1,
                                                        ), // Reducido de 2 a 1
                                                        Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                            horizontal:
                                                                4, // Reducido de 6 a 4
                                                            vertical:
                                                                1, // Reducido de 2 a 1
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .green[100],
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
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
                                                              color: Colors
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
                                                      color: Colors.green[100],
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.person,
                                                      color: Colors.green[700],
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
                                          Text(
                                            _estadoActual.toUpperCase(),
                                            style: TextStyle(
                                              color: _getColorEstado(
                                                  _estadoActual),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
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
                                  height: constraints.maxHeight *
                                      0.75, // Aumentado a 75% para un mapa más grande
                                  child: Stack(
                                    children: [
                                      FlutterMap(
                                        mapController: _mapController,
                                        options: MapOptions(
                                          center: LatLng(
                                              widget.alerta.lat ?? -12.0464,
                                              widget.alerta.lng ?? -77.0428),
                                          zoom:
                                              16, // Zoom inicial centrado en el incidente desde el primer momento
                                          onMapReady: () {
                                            // Centrar inmediatamente cuando el mapa esté listo
                                            _centrarMapaInicial();
                                            print(
                                                '📍 Mapa listo - aplicando centrado automático en incidente');

                                            // **SOLUCIÓN ADICIONAL PARA RE-ENTRADA**
                                            // Centrado final después de que todo esté completamente listo
                                            Future.delayed(
                                                Duration(milliseconds: 2000),
                                                () {
                                              if (mounted &&
                                                  widget.alerta.lat != null &&
                                                  widget.alerta.lng != null) {
                                                final puntoIncidente = LatLng(
                                                    widget.alerta.lat!,
                                                    widget.alerta.lng!);
                                                _mapController.move(
                                                    puntoIncidente, 16.0);
                                                print(
                                                    '🎆 Centrado final de seguridad aplicado para re-entrada');
                                              }
                                            });
                                          },
                                          // Configuración para mantener el centrado en el incidente
                                          keepAlive: true,
                                          // Permitir interacción pero mantener foco en el incidente
                                          interactiveFlags: InteractiveFlag.all,
                                          // Zoom mínimo y máximo apropiados para visualizar el incidente
                                          minZoom: 12.0,
                                          maxZoom: 18.0,
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate: AppConfig.mapTileUrl,
                                            subdomains: AppConfig.mapSubdomains,
                                            userAgentPackageName:
                                                'com.example.geo_app',
                                            retinaMode: true,
                                            maxZoom:
                                                17, // Reducir zoom máximo para evitar problemas
                                            // Ocultar la atribución "Mapa OSM"
                                            tileProvider: NetworkTileProvider(),
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
                                                  builder: (ctx) => Column(
                                                    children: [
                                                      Icon(
                                                        Icons.local_police,
                                                        color: Colors.blue,
                                                        size: 40,
                                                      ),
                                                      Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                          horizontal: 4,
                                                          vertical: 2,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.blue,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            4,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          'POLICÍA',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (_ubicacionAlerta != null)
                                                Marker(
                                                  width: 60.0,
                                                  height: 60.0,
                                                  point: _ubicacionAlerta!,
                                                  builder: (ctx) => Container(
                                                    alignment: Alignment.center,
                                                    child: Stack(
                                                      alignment:
                                                          Alignment.center,
                                                      children: [
                                                        // Marcador principal con sombra
                                                        Container(
                                                          width: 50,
                                                          height: 50,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.red,
                                                            shape:
                                                                BoxShape.circle,
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black54,
                                                                offset: Offset(
                                                                    2, 2),
                                                                blurRadius: 6,
                                                              ),
                                                              BoxShadow(
                                                                color: Colors
                                                                    .red
                                                                    .withOpacity(
                                                                        0.4),
                                                                offset: Offset(
                                                                    0, 0),
                                                                blurRadius: 12,
                                                                spreadRadius: 2,
                                                              ),
                                                            ],
                                                          ),
                                                          child: Icon(
                                                            Icons.emergency,
                                                            color: Colors.white,
                                                            size: 30,
                                                          ),
                                                        ),
                                                        // Punto central exacto
                                                        Container(
                                                          width: 6,
                                                          height: 6,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white,
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                                color:
                                                                    Colors.red,
                                                                width: 1),
                                                          ),
                                                        ),
                                                        // Etiqueta inferior
                                                        Positioned(
                                                          bottom: -5,
                                                          child: Container(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                              horizontal: 4,
                                                              vertical: 2,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.red,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                            ),
                                                            child: Text(
                                                              'EMERGENCIA',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
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
                                      // Overlay para ocultar completamente cualquier atribución
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        child: Container(
                                          width: 120,
                                          height: 30,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
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
                              mainAxisSize: MainAxisSize
                                  .min, // ← evita expansión innecesaria
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: ElevatedButton.icon(
                                        onPressed: _actualizandoEstado ||
                                                _cargandoRuta ||
                                                !mounted
                                            ? null
                                            : () {
                                                if (mounted) {
                                                  _centrarEnIncidente();
                                                  // Mostrar mensaje de confirmación mejorado
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .center_focus_strong,
                                                              color:
                                                                  Colors.white,
                                                              size: 16),
                                                          SizedBox(width: 8),
                                                          Text(
                                                              '🎯 Centrando manualmente en el incidente'),
                                                        ],
                                                      ),
                                                      backgroundColor:
                                                          Colors.orange[600],
                                                      duration:
                                                          Duration(seconds: 2),
                                                    ),
                                                  );
                                                }
                                              },
                                        icon: Icon(
                                          Icons.center_focus_strong,
                                          size: 16,
                                        ),
                                        label: Text('Centrar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors
                                              .orange[600], // Color más visible
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
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: _actualizandoEstado ||
                                                _cargandoRuta ||
                                                !mounted
                                            ? null
                                            : () {
                                                if (mounted)
                                                  _obtenerRutaConGPS();
                                              },
                                        icon: _cargandoRuta
                                            ? SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Icon(Icons.route, size: 16),
                                        label: Text(_cargandoRuta
                                            ? 'Calculando...'
                                            : 'GPS + Ruta'),
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
        'texto': 'Ir al Lugar y Atender Alerta',
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
        // Si está en camino y va a completar, mostrar opción de evidencia
        if (_estadoActual == 'en camino' &&
            siguienteEstado['estado'] == 'atendida') ...[
          // Sección de detalles de atención (obligatorio)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.orange[700], size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Detalles de Atención (Obligatorio)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                    Text(
                      ' *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _detallesAtencionController,
                  maxLength: 500,
                  maxLines: 4,
                  onChanged: (value) {
                    setState(() {
                      _detallesValidos = value.trim().length >= 10;
                    });
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Describa los detalles de la atención realizada, acciones tomadas, estado del incidente, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.orange[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.orange[600]!, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    errorText: _detallesAtencionController.text.isNotEmpty &&
                            !_detallesValidos
                        ? 'Mínimo 10 caracteres requeridos'
                        : null,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Mínimo 10 caracteres, máximo 500. Incluya información relevante sobre la situación atendida.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Sección de evidencia (opcional)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
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
                    Icon(Icons.camera_alt, color: Colors.blue[700], size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Evidencia (Opcional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Puedes adjuntar evidencia del incidente resuelto (foto, documento, etc.)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                  ),
                ),
                SizedBox(height: 12),

                // Botón para seleccionar archivo
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _actualizandoEstado ? null : seleccionarArchivo,
                    icon: Icon(
                      (_archivoSeleccionado != null || _archivoWebBytes != null)
                          ? Icons.check_circle
                          : Icons.attach_file,
                      size: 18,
                    ),
                    label: Text(
                      (_archivoSeleccionado != null || _archivoWebBytes != null)
                          ? 'Archivo seleccionado: ${_nombreArchivoWeb ?? _archivoSeleccionado?.path.split('/').last ?? 'archivo'}'
                          : 'Seleccionar Evidencia',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: (_archivoSeleccionado != null ||
                              _archivoWebBytes != null)
                          ? Colors.green[700]
                          : Colors.blue[700],
                      side: BorderSide(
                        color: (_archivoSeleccionado != null ||
                                _archivoWebBytes != null)
                            ? Colors.green[300]!
                            : Colors.blue[300]!,
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),

                // Mostrar información si hay archivo seleccionado
                if (_archivoSeleccionado != null ||
                    _archivoWebBytes != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.green[700]),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'La evidencia se subirá automáticamente al completar la atención',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                        // Botón para quitar archivo
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _archivoSeleccionado = null;
                              _archivoWebBytes = null;
                              _nombreArchivoWeb = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Archivo removido'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          icon: Icon(Icons.close, size: 16),
                          padding: EdgeInsets.zero,
                          constraints:
                              BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Botón principal de acción
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _actualizandoEstado || !mounted
                ? null
                : () {
                    // Validar detalles de atención si es necesario
                    if (siguienteEstado!['estado'] == 'atendida' &&
                        !_detallesValidos) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '📝 Debe completar los detalles de atención antes de finalizar (mínimo 10 caracteres)',
                          ),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    if (mounted)
                      _actualizarEstadoAlerta(siguienteEstado['estado']);
                  },
            icon: _actualizandoEstado
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';

import '../models/alerta_model.dart';
import '../services/alerta_service.dart';
import '../services/user_service.dart';
import 'ruta_atencion_screen.dart';

class AlertaPoliceScreen extends StatefulWidget {
  const AlertaPoliceScreen({super.key});

  @override
  State<AlertaPoliceScreen> createState() => _AlertaPoliceScreenState();
}

class _AlertaPoliceScreenState extends State<AlertaPoliceScreen> {
  late Future<List<Alerta>> _alertasFuture;
  final Map<String, String> _nombresUsuarios = {};
  final Map<String, MapController> _mapControllers =
      {}; // Controladores de mapa por alerta
  String?
      _alertaIdEspecifica; // ID de alerta específica si se pasa como parámetro

  @override
  void initState() {
    super.initState();
    // La carga de alertas se hará en didChangeDependencies para acceder a los argumentos
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Obtener argumentos de la ruta si existen
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map<String, dynamic>) {
      _alertaIdEspecifica = arguments['alertaId'];
      print(
          '🎯 AlertaPoliceScreen - Alerta específica recibida: $_alertaIdEspecifica');
    }

    _cargarAlertas();
  }

  void _cargarAlertas() {
    _alertasFuture = _cargarAlertasConNombres();
  }

  @override
  void dispose() {
    // Limpiar todos los controladores de mapa
    _mapControllers.values.forEach((controller) {
      controller.dispose();
    });
    _mapControllers.clear();
    super.dispose();
  }

  Future<List<Alerta>> _cargarAlertasConNombres() async {
    try {
      // Cargar todas las alertas pendientes
      final todasLasAlertas = await AlertaService().obtenerAlertasPendientes();

      List<Alerta> alertas;

      // Si hay una alerta específica, filtrar por ella
      if (_alertaIdEspecifica != null && _alertaIdEspecifica!.isNotEmpty) {
        print('🔍 Filtrando por alerta específica: $_alertaIdEspecifica');
        alertas = todasLasAlertas
            .where((alerta) => alerta.id == _alertaIdEspecifica)
            .toList();

        if (alertas.isEmpty) {
          print(
              '⚠️ Alerta específica no encontrada en alertas pendientes, mostrando todas');
          alertas = todasLasAlertas;
        } else {
          print('✅ Alerta específica encontrada');
        }
      } else {
        // Usar todas las alertas pendientes
        alertas = todasLasAlertas;
      }

      // Debug: Verificar datos de alertas
      print('=== DEBUG ALERTAS POLICÍA ===');
      print('Total alertas obtenidas: ${alertas.length}');
      if (_alertaIdEspecifica != null) {
        print('Filtro aplicado para alerta: $_alertaIdEspecifica');
      }

      for (var alerta in alertas) {
        print('Alerta ID: ${alerta.id}');
        print('  - Detalle: ${alerta.detalle}');
        print('  - Coordenadas: lat=${alerta.lat}, lng=${alerta.lng}');
        print('  - Dirección (campo original): "${alerta.direccion}"');
        print('  - Dirección completa (getter): "${alerta.direccionCompleta}"');
        print('  - Dirección mejorada: "${_construirDireccionMejor(alerta)}"');
        print('  - Campos individuales:');
        print('    * Calle: "${alerta.calle ?? 'null'}"');
        print('    * Barrio: "${alerta.barrio ?? 'null'}"');
        print('    * Ciudad: "${alerta.ciudad ?? 'null'}"');
        print('    * Estado: "${alerta.estado ?? 'null'}"');
        print('    * País: "${alerta.pais ?? 'null'}"');
        print('    * Código Postal: "${alerta.codigoPostal ?? 'null'}"');
        print('  - Status: ${alerta.status}');
        print('  ---');
      }

      // Si no hay alertas del servidor, usar alertas de prueba locales
      if (alertas.isEmpty) {
        print('No hay alertas del servidor, usando alertas de prueba locales');
        return _crearAlertasDePruebaLocal();
      }

      // Cargar nombres de usuarios para cada alerta
      for (var alerta in alertas) {
        if (!_nombresUsuarios.containsKey(alerta.usuarioCreador)) {
          try {
            final usuario = await UserService.obtenerUsuarioActual(
              alerta.usuarioCreador,
            );
            if (usuario != null) {
              _nombresUsuarios[alerta.usuarioCreador] = usuario.fullName;
            }
          } catch (e) {
            print('Error al obtener usuario ${alerta.usuarioCreador}: $e');
            _nombresUsuarios[alerta.usuarioCreador] = 'Usuario desconocido';
          }
        }
      }

      return alertas;
    } catch (e) {
      print('Error cargando alertas del servidor: $e');
      print('Usando alertas de prueba locales como fallback');
      return _crearAlertasDePruebaLocal();
    }
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
      default:
        return 0;
    }
  }

  Future<void> actualizarEstado(Alerta alerta, String nuevoEstado) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final policiaId = prefs.getString('userId') ?? '';

    double? origenLat, origenLng;

    if (nuevoEstado == 'en camino') {
      Position posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      origenLat = posicion.latitude;
      origenLng = posicion.longitude;
    }

    final actualizado = await AlertaService().actualizarEstado(
      alerta.id,
      nuevoEstado,
      policiaId,
      origenLat: origenLat,
      origenLng: origenLng,
      destinoLat: alerta.lat,
      destinoLng: alerta.lng,
    );

    if (actualizado) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Estado actualizado')));
      setState(() {
        _cargarAlertas();
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al actualizar estado')));
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendiente':
        return Colors.orange;
      case 'asignado':
        return Colors.blue;
      case 'en camino':
        return Colors.green;
      case 'atendida':
        return Colors.grey;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String titulo =
        _alertaIdEspecifica != null ? 'Alerta Específica' : 'Atender Alertas';

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: _alertaIdEspecifica != null ? Colors.blue[700] : null,
        foregroundColor: _alertaIdEspecifica != null ? Colors.white : null,
      ),
      body: FutureBuilder<List<Alerta>>(
        future: _alertasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(_alertaIdEspecifica != null
                      ? 'Cargando alerta específica...'
                      : 'Cargando alertas...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            print('❌ Error en FutureBuilder: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error al cargar alertas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final alertas = snapshot.data;
          if (alertas == null || alertas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    _alertaIdEspecifica != null
                        ? 'Alerta no encontrada'
                        : 'No hay alertas pendientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_alertaIdEspecifica != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'La alerta con ID $_alertaIdEspecifica no está disponible',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                            context, '/atender-alerta');
                      },
                      icon: Icon(Icons.list),
                      label: Text('Ver todas las alertas'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: alertas.length,
            itemBuilder: (context, index) {
              final alerta = alertas[index];
              final bool esAlertaEspecifica = _alertaIdEspecifica != null &&
                  alerta.id == _alertaIdEspecifica;

              return Card(
                margin: EdgeInsets.all(8),
                elevation: esAlertaEspecifica ? 8 : 2,
                color: esAlertaEspecifica ? Colors.blue[50] : null,
                shape: esAlertaEspecifica
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue, width: 2),
                      )
                    : null,
                child: Column(
                  children: [
                    // Indicador de alerta específica si aplica
                    if (esAlertaEspecifica)
                      Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.push_pin, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Alerta seleccionada desde notificaciones',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Información compacta de la alerta
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título y estado en una fila
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  alerta.detalle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(alerta.status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  alerta.status.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),

                          // Información básica en filas compactas
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Usuario: ${_nombresUsuarios[alerta.usuarioCreador] ?? alerta.usuarioCreador}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Spacer(),
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4),
                              Text(
                                alerta.fechaHora.toString().substring(5, 16),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),

                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.blue[700],
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _construirDireccionMejor(alerta),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.directions,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RutaAtencionScreen(
                                        alerta: alerta,
                                      ),
                                    ),
                                  );
                                },
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Indicador de progreso compacto
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: StepProgressIndicator(
                        totalSteps: 4,
                        currentStep: obtenerPasoEstado(alerta.status),
                        selectedColor: Colors.blue,
                        unselectedColor: Colors.grey[300]!,
                        size: 4,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Mapa más grande
                    SizedBox(height: 250, child: _buildMapaAlerta(alerta)),

                    // Botones de acción compactos
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RutaAtencionScreen(alerta: alerta),
                                  ),
                                ).then((_) {
                                  setState(() {
                                    _cargarAlertas();
                                  });
                                });
                              },
                              icon: Icon(Icons.navigation, size: 16),
                              label: Text(
                                'ATENDER',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: _buildBotonEstadoCompacto(alerta),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBotonEstadoCompacto(Alerta alerta) {
    // Para el rol de policía, siempre mostrar el botón "CENTRAR MAPA"
    // Esto permite que el gendarme pueda centrar el mapa en cualquier momento
    return ElevatedButton(
      onPressed: () => _centrarMapaEnAlerta(alerta),
      child: Text(
        'CENTRAR MAPA',
        style: TextStyle(fontSize: 11),
        textAlign: TextAlign.center,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  // Función para centrar el mapa en la ubicación de la alerta
  void _centrarMapaEnAlerta(Alerta alerta) {
    if (alerta.lat == null || alerta.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Esta alerta no tiene coordenadas GPS disponibles'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Verificar que el controlador existe
    if (_mapControllers.containsKey(alerta.id)) {
      final mapController = _mapControllers[alerta.id]!;

      try {
        // Coordenadas exactas del incidente
        final puntoIncidente = LatLng(alerta.lat!, alerta.lng!);

        print('🎯 Centrando mapa en: Lat: ${alerta.lat}, Lng: ${alerta.lng}');

        // Primero hacer un zoom out y luego centrar con animación suave
        // Esto asegura que el punto se centre correctamente
        Future.microtask(() {
          // Primer movimiento: zoom moderado para preparar
          mapController.move(puntoIncidente, 14.0);

          // Segundo movimiento después de un pequeño delay: zoom final con centrado preciso
          Future.delayed(Duration(milliseconds: 300), () {
            if (mounted) {
              // Centrado final con zoom moderado que muestre bien el contexto
              mapController.move(
                puntoIncidente,
                15.5, // Zoom más bajo para ver mejor el punto y el contexto alrededor
              );

              // Forzar otro centrado después de un momento para asegurar precisión
              Future.delayed(Duration(milliseconds: 400), () {
                if (mounted) {
                  mapController.move(puntoIncidente, 15.5);
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
                        'Coordenadas: ${alerta.lat!.toStringAsFixed(6)}, ${alerta.lng!.toStringAsFixed(6)}',
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
        print('Error al centrar el mapa: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al centrar el mapa'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Mapa no disponible para centrar'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildMapaAlerta(Alerta alerta) {
    // Verificar si tenemos coordenadas válidas
    bool tieneCoordenadasValidas = alerta.lat != null &&
        alerta.lng != null &&
        alerta.lat != 0 &&
        alerta.lng != 0 &&
        alerta.lat!.abs() <= 90 &&
        alerta.lng!.abs() <= 180;

    if (!tieneCoordenadasValidas) {
      // Si no tenemos coordenadas válidas, mostrar mensaje
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 50, color: Colors.grey[400]),
              SizedBox(height: 12),
              Text(
                'Ubicación no disponible',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              if (alerta.direccion.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    alerta.direccion,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Text(
                  'Coordenadas GPS no disponibles',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } // Si tenemos coordenadas válidas, mostrar el mapa directamente
    try {
      // Crear o obtener el controlador de mapa para esta alerta específica
      if (!_mapControllers.containsKey(alerta.id)) {
        _mapControllers[alerta.id] = MapController();
      }

      final mapController = _mapControllers[alerta.id]!;

      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Mapa principal con configuración optimizada para ver el incidente
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  center: LatLng(alerta.lat!, alerta.lng!),
                  zoom:
                      16.5, // Zoom inicial que muestre claramente el punto del incidente
                  minZoom: 8.0,
                  maxZoom: 17.0, // Reducir más el zoom máximo
                  interactiveFlags: InteractiveFlag.all,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.geo_app',
                    maxZoom: 18,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width:
                            60.0, // Reducir tamaño para que sea más proporcionado
                        height: 60.0,
                        point: LatLng(alerta.lat!, alerta.lng!),
                        builder: (ctx) => Container(
                          // Centrar el marcador exactamente en las coordenadas
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Círculo de pulso exterior reducido
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                              // Círculo de fondo principal más pequeño
                              Container(
                                width:
                                    35, // Tamaño similar al de la pantalla izquierda
                                height: 35,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black54,
                                      offset: Offset(2, 2),
                                      blurRadius: 6,
                                    ),
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.4),
                                      offset: Offset(0, 0),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 22, // Icono más pequeño y proporcionado
                                ),
                              ),
                              // Punto central más pequeño
                              Container(
                                width: 6, // Punto central del tamaño original
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.red, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      offset: Offset(1, 1),
                                      blurRadius: 1,
                                    ),
                                  ],
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
              // Indicador de coordenadas en la esquina superior derecha
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '${alerta.lat!.toStringAsFixed(4)}, ${alerta.lng!.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error al construir el mapa: $e');
      return _buildMapaFallback(alerta);
    }
  }

  Widget _buildMapaFallback(Alerta alerta) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[50]!, Colors.blue[100]!],
        ),
      ),
      child: Stack(
        children: [
          // Fondo de mapa simplificado
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(2, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(Icons.location_on, color: Colors.white, size: 40),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    'Ubicación de la Alerta',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Coordenadas en la esquina
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '${alerta.lat!.toStringAsFixed(4)}, ${alerta.lng!.toStringAsFixed(4)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _construirDireccionMejor(Alerta alerta) {
    // Priorizar el campo 'direccion' si contiene información completa
    if (alerta.direccion.isNotEmpty &&
        alerta.direccion.contains(',') &&
        !alerta.direccion.contains('Lat:')) {
      return alerta.direccion;
    }

    // Si no, construir desde campos individuales
    List<String> partes = [];

    if (alerta.calle != null && alerta.calle!.isNotEmpty) {
      partes.add(alerta.calle!);
    }
    if (alerta.barrio != null && alerta.barrio!.isNotEmpty) {
      partes.add(alerta.barrio!);
    }
    if (alerta.ciudad != null && alerta.ciudad!.isNotEmpty) {
      partes.add(alerta.ciudad!);
    }
    if (alerta.estado != null && alerta.estado!.isNotEmpty) {
      partes.add(alerta.estado!);
    }
    if (alerta.pais != null && alerta.pais!.isNotEmpty) {
      partes.add(alerta.pais!);
    }

    if (partes.length >= 2) {
      return partes.join(', ');
    }

    // Fallback al campo direccion original
    if (alerta.direccion.isNotEmpty) {
      return alerta.direccion;
    }

    // Último recurso: coordenadas
    if (alerta.lat != null && alerta.lng != null) {
      return 'Lat: ${alerta.lat!.toStringAsFixed(4)}, Lng: ${alerta.lng!.toStringAsFixed(4)}';
    }

    return 'Ubicación no disponible';
  }

  // Método para crear alerta de prueba local si no hay conexión con el backend
  List<Alerta> _crearAlertasDePruebaLocal() {
    return [
      Alerta(
        id: 'test-1',
        direccion: '24 de Mayo, Santa Elena, Ecuador',
        usuarioCreador: 'test-user',
        fechaHora: DateTime.now(),
        detalle: 'Robo en ebanistería - Alerta de prueba',
        status: 'pendiente',
        lat: -0.1807,
        lng: -78.4678,
      ),
      Alerta(
        id: 'test-2',
        direccion: 'Av. 6 de Diciembre, Quito, Ecuador',
        usuarioCreador: 'test-user-2',
        fechaHora: DateTime.now().subtract(Duration(minutes: 30)),
        detalle: 'Accidente de tránsito - Alerta de prueba',
        status: 'pendiente',
        lat: -0.2201,
        lng: -78.5123,
      ),
      Alerta(
        id: 'test-3',
        direccion: 'Plaza Grande, Centro Histórico, Quito',
        usuarioCreador: 'test-user-3',
        fechaHora: DateTime.now().subtract(Duration(hours: 1)),
        detalle: 'Emergencia médica - Alerta de prueba',
        status: 'asignado',
        lat: -0.2202,
        lng: -78.5120,
      ),
    ];
  }
}

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

  @override
  void initState() {
    super.initState();
    _cargarAlertas();
  }

  void _cargarAlertas() {
    _alertasFuture = _cargarAlertasConNombres();
  }

  Future<List<Alerta>> _cargarAlertasConNombres() async {
    try {
      final alertas = await AlertaService().obtenerAlertasPendientes();

      // Debug: Verificar datos de alertas
      print('=== DEBUG ALERTAS POLICÍA ===');
      print('Total alertas obtenidas: ${alertas.length}');
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
    return Scaffold(
      appBar: AppBar(title: Text('Atender Alertas')),
      body: FutureBuilder<List<Alerta>>(
        future: _alertasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));

          final alertas = snapshot.data!;
          if (alertas.isEmpty)
            return Center(child: Text('No hay alertas pendientes'));

          return ListView.builder(
            itemCount: alertas.length,
            itemBuilder: (context, index) {
              final alerta = alertas[index];
              return Card(
                margin: EdgeInsets.all(8),
                child: Column(
                  children: [
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
                                      builder:
                                          (context) => RutaAtencionScreen(
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
                                    builder:
                                        (context) =>
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
    List<String> estados = ['pendiente', 'asignado', 'en camino', 'atendida'];
    int indexActual = estados.indexOf(alerta.status);

    if (indexActual == -1 || indexActual == estados.length - 1) {
      return SizedBox(); // Ya está en el último estado
    }

    String siguienteEstado = estados[indexActual + 1];

    return ElevatedButton(
      onPressed: () => actualizarEstado(alerta, siguienteEstado),
      child: Text(
        _getTextoSiguienteEstado(siguienteEstado),
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

  String _getTextoSiguienteEstado(String estado) {
    switch (estado) {
      case 'asignado':
        return 'ASIGNAR';
      case 'en camino':
        return 'IR';
      case 'atendida':
        return 'ATENDER';
      default:
        return estado.toUpperCase();
    }
  }

  Widget _buildMapaAlerta(Alerta alerta) {
    // Verificar si tenemos coordenadas válidas
    bool tieneCoordenadasValidas =
        alerta.lat != null &&
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
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Mapa principal con configuración simplificada
              FlutterMap(
                options: MapOptions(
                  center: LatLng(alerta.lat!, alerta.lng!),
                  zoom: 15.0,
                  minZoom: 8.0,
                  maxZoom: 18.0,
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
                        width: 60.0,
                        height: 60.0,
                        point: LatLng(alerta.lat!, alerta.lng!),
                        builder:
                            (ctx) => Container(
                              child: Column(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          offset: Offset(2, 2),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  Container(
                                    width: 4,
                                    height: 8,
                                    color: Colors.red,
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
              // Indicador de estado del mapa
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Mapa OSM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
          // Indicador de mapa simplificado
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[600],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Vista simplificada',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';

import '../models/alerta_model.dart';
import '../services/alerta_service.dart';
import 'ruta_atencion_screen.dart';

class AlertaPoliceScreen extends StatefulWidget {
  const AlertaPoliceScreen({super.key});

  @override
  State<AlertaPoliceScreen> createState() => _AlertaPoliceScreenState();
}

class _AlertaPoliceScreenState extends State<AlertaPoliceScreen> {
  late Future<List<Alerta>> _alertasFuture;

  @override
  void initState() {
    super.initState();
    _cargarAlertas();
  }

  void _cargarAlertas() {
    _alertasFuture = AlertaService().obtenerAlertasPendientes();
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
                                'Usuario: ${alerta.usuarioCreador}',
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
                                  alerta.direccion,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                  ),
                                  maxLines: 1,
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
                    SizedBox(
                      height: 250, // Aumentado de 200 a 250
                      child: FlutterMap(
                        options: MapOptions(
                          center: LatLng(alerta.lat ?? 0, alerta.lng ?? 0),
                          zoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: ['a', 'b', 'c'],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(alerta.lat ?? 0, alerta.lng ?? 0),
                                builder:
                                    (ctx) => Icon(
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
}

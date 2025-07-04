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
                margin: EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        alerta.detalle,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estado: ${alerta.status}'),
                          Text('Usuario: ${alerta.usuarioCreador}'),
                          Text(
                            'Fecha: ${alerta.fechaHora.toString().substring(0, 16)}',
                          ),
                          Text(
                            'Ubicación: ${alerta.direccionCompleta}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.directions, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      RutaAtencionScreen(alerta: alerta),
                            ),
                          );
                        },
                      ),
                    ),
                    StepProgressIndicator(
                      totalSteps: 4,
                      currentStep: obtenerPasoEstado(alerta.status),
                      selectedColor: Colors.blue,
                      unselectedColor: Colors.grey[300]!,
                      customStep: (index, color, _) {
                        List<String> labels = [
                          'Pendiente',
                          'Asignado',
                          'En Camino',
                          'Atendida',
                        ];
                        return Container(
                          color: color,
                          child: Center(
                            child: Text(
                              labels[index],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(
                      height: 200,
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
                    SizedBox(height: 10),

                    // Botón principal para atender alerta
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
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
                                  // Recargar alertas cuando regrese
                                  setState(() {
                                    _cargarAlertas();
                                  });
                                });
                              },
                              icon: Icon(Icons.navigation),
                              label: Text('ATENDER ALERTA'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildBotonesEstado(alerta),
                    SizedBox(height: 10),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBotonesEstado(Alerta alerta) {
    List<String> estados = ['pendiente', 'asignado', 'en camino', 'atendida'];

    int indexActual = estados.indexOf(alerta.status);
    if (indexActual == -1 || indexActual == estados.length - 1) {
      return SizedBox(); // Ya está en el último estado
    }

    String siguienteEstado = estados[indexActual + 1];

    return ElevatedButton(
      onPressed: () => actualizarEstado(alerta, siguienteEstado),
      child: Text('Pasar a "$siguienteEstado"'),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:geo_app/screens/alerta_form_screen.dart';

import '../models/alerta_model.dart';
import '../services/alerta_service.dart';
import 'alerta_map_screen.dart';

class AlertaListScreen extends StatefulWidget {
  final String userId;

  AlertaListScreen({required this.userId});

  @override
  _AlertaListScreenState createState() => _AlertaListScreenState();
}

class _AlertaListScreenState extends State<AlertaListScreen> {
  late Future<List<Alerta>> _alertasFuture;

  @override
  void initState() {
    super.initState();
    _alertasFuture = AlertaService().obtenerAlertasPorUsuario(widget.userId);
  }

  // Función para extraer lat y lng de la dirección tipo "Lat: -0.1006592, Lng: -78.4844181"
  List<double>? extraerLatLng(String direccion) {
    try {
      final latMatch = RegExp(r'Lat:\s*(-?\d+\.?\d*)').firstMatch(direccion);
      final lngMatch = RegExp(r'Lng:\s*(-?\d+\.?\d*)').firstMatch(direccion);
      if (latMatch != null && lngMatch != null) {
        final lat = double.parse(latMatch.group(1)!);
        final lng = double.parse(lngMatch.group(1)!);
        return [lat, lng];
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mis Alertas')),
      body: FutureBuilder<List<Alerta>>(
        future: _alertasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));

          final alertas = snapshot.data!;
          if (alertas.isEmpty) {
            return Center(child: Text('No hay alertas registradas'));
          }

          return ListView.builder(
            itemCount: alertas.length,
            itemBuilder: (context, index) {
              final alerta = alertas[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  title: Text(
                    alerta.detalle.isNotEmpty ? alerta.detalle : 'Sin detalle',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 6),
                      Text(
                        'Estado: ${alerta.status.isNotEmpty ? alerta.status : 'desconocido'}',
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Fecha: ${alerta.fechaHora.toLocal().toString().split(".")[0]}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    child: Text('Ver Ubicación'),
                    onPressed: () {
                      final coords = extraerLatLng(alerta.direccion);
                      if (coords != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AlertaMapScreen(alerta: alerta),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Coordenadas inválidas')),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AlertaFormScreen(userId: widget.userId),
            ),
          );
          setState(() {
            _alertasFuture = AlertaService().obtenerAlertasPorUsuario(
              widget.userId,
            );
          });
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/alerta_model.dart';

class AlertaMapScreen extends StatelessWidget {
  final Alerta alerta;

  const AlertaMapScreen({Key? key, required this.alerta}) : super(key: key);

  LatLng _parseLatLng(String direccion) {
    // Ejemplo: "Lat: -0.1006592, Lng: -78.4844181"
    final regex = RegExp(r'Lat:\s*([-\d\.]+),\s*Lng:\s*([-\d\.]+)');
    final match = regex.firstMatch(direccion);
    if (match != null) {
      final lat = double.parse(match.group(1)!);
      final lng = double.parse(match.group(2)!);
      return LatLng(lat, lng);
    }
    // fallback
    return LatLng(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final puntoAlerta = _parseLatLng(alerta.direccion);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ubicación de la Alerta'),
      ),
      body: FlutterMap(
        options: MapOptions(
          center: puntoAlerta,
          zoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.tuempresa.geo_app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 80,
                height: 80,
                point: puntoAlerta,
                builder: (ctx) => Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/alerta_model.dart';
import '../services/alerta_service.dart';
import 'alerta_form_screen.dart';
import 'alerta_tracking_screen.dart';

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

  /// Método que maneja la navegación para crear una nueva alerta
  /// Se ejecuta cuando se presiona el botón "Generar Alerta"
  Future<void> _navegarAFormularioAlerta() async {
    // Navegamos al formulario de creación de alerta
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlertaFormScreen(userId: widget.userId),
      ),
    );

    // Actualizamos la lista de alertas después de regresar del formulario
    setState(() {
      _alertasFuture = AlertaService().obtenerAlertasPorUsuario(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Alertas'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _alertasFuture =
                    AlertaService().obtenerAlertasPorUsuario(widget.userId);
              });
            },
            tooltip: 'Actualizar alertas',
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner informativo
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(
                bottom: BorderSide(color: Colors.blue[200]!),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aquí puedes ver todas tus alertas y hacer seguimiento en tiempo real',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de alertas
          Expanded(
            child: FutureBuilder<List<Alerta>>(
              future: _alertasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.red[700]),
                        SizedBox(height: 16),
                        Text('Cargando tus alertas...'),
                      ],
                    ),
                  );
                if (snapshot.hasError)
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _alertasFuture = AlertaService()
                                  .obtenerAlertasPorUsuario(widget.userId);
                            });
                          },
                          child: Text('Reintentar'),
                        ),
                      ],
                    ),
                  );

                final alertas = snapshot.data!;
                if (alertas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No tienes alertas registradas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Cuando crees una alerta de emergencia,\naparecerá aquí para hacer seguimiento',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _navegarAFormularioAlerta,
                          icon: Icon(Icons.add_alert),
                          label: Text('Crear Primera Alerta'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: alertas.length,
                  itemBuilder: (context, index) {
                    final alerta = alertas[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AlertaTrackingScreen(alerta: alerta),
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header con estado
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(alerta.status),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _getStatusText(alerta.status),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),

                              SizedBox(height: 12),

                              // Descripción de la alerta
                              Text(
                                alerta.detalle.isNotEmpty
                                    ? alerta.detalle
                                    : 'Sin descripción',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              SizedBox(height: 8),

                              // Fecha y ubicación
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    alerta.fechaHora
                                        .toLocal()
                                        .toString()
                                        .split(".")[0],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
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
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      alerta.direccion,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 12),

                              // Botón de acción
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AlertaTrackingScreen(
                                            alerta: alerta),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.track_changes),
                                  label: Text('Ver Seguimiento'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[600],
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarAFormularioAlerta,
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_alert),
        label: Text('Nueva Alerta'),
      ),
    );
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

  String _getStatusText(String status) {
    switch (status) {
      case 'pendiente':
        return 'PENDIENTE';
      case 'asignado':
        return 'ASIGNADO';
      case 'en camino':
        return 'EN CAMINO';
      case 'atendida':
        return 'ATENDIDA';
      case 'cancelada':
        return 'CANCELADA';
      default:
        return 'DESCONOCIDO';
    }
  }
}

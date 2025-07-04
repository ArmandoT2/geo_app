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
      appBar: AppBar(title: Text('Mis Alertas')),
      body: Stack(
        children: [
          // CONTENIDO PRINCIPAL: Lista de alertas
          FutureBuilder<List<Alerta>>(
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
                // Agregamos padding inferior para evitar que el último elemento quede oculto detrás del botón
                padding: EdgeInsets.only(bottom: 80),
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
                        alerta.detalle.isNotEmpty
                            ? alerta.detalle
                            : 'Sin detalle',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        child: Text('Ver Seguimiento'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => AlertaTrackingScreen(alerta: alerta),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // BOTÓN PERSONALIZADO: Posicionado en la parte inferior centrada
          Positioned(
            // Posicionamos el botón a 16px del fondo de la pantalla
            bottom: 16,
            // Centramos horizontalmente usando left y right
            left: 20,
            right: 20,
            child: Center(
              child: AnimatedContainer(
                // Contenedor animado para efectos de hover/press
                duration: Duration(milliseconds: 200),
                child: Material(
                  // Material para poder usar InkWell y obtener efectos visuales
                  borderRadius: BorderRadius.circular(30),
                  elevation:
                      6, // Sombra para simular elevación del FloatingActionButton
                  child: InkWell(
                    // InkWell proporciona el efecto de ondas (ripple effect) al tocar
                    borderRadius: BorderRadius.circular(30),
                    onTap: _navegarAFormularioAlerta,
                    // Efecto hover para cambiar la elevación (solo en web/desktop)
                    onHover: (isHovering) {
                      // Este setState crea un micro-rebuild para el efecto hover
                      setState(() {
                        // El efecto se maneja visualmente por el InkWell
                      });
                    },
                    child: Container(
                      // Contenedor principal del botón
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        // Gradiente para hacer el botón más atractivo
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        // Sombra adicional para profundidad
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min, // El botón se ajusta al contenido
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ícono de alerta para complementar el texto
                          Icon(Icons.add_alert, color: Colors.white, size: 24),
                          SizedBox(width: 12), // Espacio entre ícono y texto
                          // Texto principal del botón
                          Text(
                            'Generar Alerta',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing:
                                  0.5, // Espaciado entre letras para mejor legibilidad
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

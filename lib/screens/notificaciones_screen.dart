import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/contacto_service.dart';
import '../widgets/common_widgets.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<Map<String, dynamic>> _notificaciones = [];
  bool _cargando = true;
  String _userId = '';
  Timer? _refreshTimer;
  final ContactoService _contactoService = ContactoService();

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
    _iniciarRefreshAutomatico();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _iniciarRefreshAutomatico() {
    // Refresh cada 30 segundos para notificaciones en tiempo real
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _cargarNotificaciones(mostrarCarga: false);
      }
    });
  }

  Future<void> _cargarNotificaciones({bool mostrarCarga = true}) async {
    if (!mounted) return;

    if (mostrarCarga) {
      setState(() {
        _cargando = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId') ?? '';

      if (_userId.isNotEmpty) {
        final notificaciones = await _contactoService
            .obtenerNotificacionesPendientes(_userId);

        if (mounted) {
          setState(() {
            _notificaciones = notificaciones;
            _cargando = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cargando = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
        });

        if (mostrarCarga) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar notificaciones: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _marcarComoLeida(String notificacionId, int index) async {
    try {
      final marcada = await _contactoService.marcarNotificacionLeida(
        notificacionId,
      );

      if (marcada && mounted) {
        setState(() {
          _notificaciones.removeAt(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Notificación marcada como leída'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al marcar notificación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones de Emergencia'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          if (_notificaciones.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_notificaciones.length}',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarNotificaciones,
          ),
        ],
      ),
      body:
          _cargando
              ? LoadingWidget(message: 'Cargando notificaciones...')
              : _notificaciones.isEmpty
              ? EmptyStateWidget(
                title: 'No tienes notificaciones',
                subtitle:
                    'Aquí aparecerán las alertas de emergencia de tus contactos',
                icon: Icons.notifications_none,
                onRefresh: _cargarNotificaciones,
              )
              : RefreshIndicator(
                onRefresh: _cargarNotificaciones,
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _notificaciones.length,
                  itemBuilder: (context, index) {
                    final notificacion = _notificaciones[index];
                    return _buildNotificacionCard(notificacion, index);
                  },
                ),
              ),
    );
  }

  Widget _buildNotificacionCard(Map<String, dynamic> notificacion, int index) {
    final fechaHora =
        DateTime.tryParse(notificacion['fecha_hora'] ?? '') ?? DateTime.now();
    final tiempoTranscurrido = _calcularTiempoTranscurrido(fechaHora);

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de la notificación
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.emergency, color: Colors.white, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🚨 ALERTA DE EMERGENCIA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'De: ${notificacion['nombre_contacto'] ?? 'Contacto'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed:
                      () => _marcarComoLeida(
                        notificacion['id']?.toString() ?? '',
                        index,
                      ),
                  tooltip: 'Marcar como leída',
                ),
              ],
            ),

            SizedBox(height: 16),

            // Detalles de la alerta
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalles:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    notificacion['detalle'] ?? 'Sin detalles',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

            // Información adicional
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.access_time,
                    tiempoTranscurrido,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    Icons.category,
                    notificacion['tipo_alerta'] ?? 'Emergencia',
                    Colors.orange,
                  ),
                ),
              ],
            ),

            if (notificacion['latitud'] != null &&
                notificacion['longitud'] != null) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ubicación registrada',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Lat: ${notificacion['latitud']}, Lng: ${notificacion['longitud']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // Aquí puedes abrir un mapa o Google Maps
                        _abrirUbicacion(
                          notificacion['latitud'],
                          notificacion['longitud'],
                        );
                      },
                      icon: Icon(Icons.map, size: 16),
                      label: Text('Ver', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 12),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        () => _marcarComoLeida(
                          notificacion['id']?.toString() ?? '',
                          index,
                        ),
                    icon: Icon(Icons.check, size: 16),
                    label: Text('Marcar como leída'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _contactarPersona(notificacion),
                    icon: Icon(Icons.call, size: 16),
                    label: Text('Contactar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _calcularTiempoTranscurrido(DateTime fechaHora) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fechaHora);

    if (diferencia.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} horas';
    } else {
      return 'Hace ${diferencia.inDays} días';
    }
  }

  void _abrirUbicacion(double latitud, double longitud) {
    // Aquí puedes implementar la apertura de mapas
    // Por ejemplo, usando url_launcher para abrir Google Maps
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Ubicación'),
            content: Text('Latitud: $latitud\nLongitud: $longitud'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  void _contactarPersona(Map<String, dynamic> notificacion) {
    // Aquí puedes implementar opciones para contactar a la persona
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Contactar'),
            content: Text(
              '¿Cómo deseas contactar a ${notificacion['nombre_contacto']}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Implementar llamada telefónica
                },
                child: Text('Llamar'),
              ),
            ],
          ),
    );
  }
}

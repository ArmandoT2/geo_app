import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class NotificacionesScreen extends StatefulWidget {
  @override
  _NotificacionesScreenState createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final NotificationService _notificationService = NotificationService();
  List<dynamic> _notificaciones = [];
  bool _loading = true;
  String? currentUserId;
  String? userRole;

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      _cargarNotificaciones();
    });
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('userId');
    userRole = prefs.getString('rol');
    print('👤 ID de usuario cargado desde SharedPreferences: $currentUserId');
    print('👮 Rol de usuario: $userRole');
  }

  Future<void> _cargarNotificaciones() async {
    setState(() {
      _loading = true;
    });

    try {
      print('🔄 Cargando notificaciones...');
      final notificaciones =
          await _notificationService.getUltimasNotificaciones();
      print('📋 Notificaciones recibidas: ${notificaciones.length}');

      setState(() {
        _notificaciones = notificaciones;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error cargando notificaciones: $e');
      setState(() {
        _loading = false;
      });

      // Mostrar error al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al cargar notificaciones: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _marcarComoLeida(String id) async {
    if (currentUserId == null) {
      print('❌ Error: userId no disponible');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: Usuario no identificado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _notificationService.marcarComoLeida(id, currentUserId!);
      print('✅ Notificación marcada como leída por $currentUserId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Notificación marcada como leída'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      _cargarNotificaciones(); // refrescar lista
    } catch (e) {
      print('❌ Error al marcar como leída: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al marcar como leída'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navegarAAtenderAlertas() {
    Navigator.pushNamed(context, '/atender-alerta');
  }

  void _navegarAAlertaEspecifica(String? alertaId) {
    if (alertaId != null) {
      // Navegar directamente a la pantalla de atender alertas
      // En una implementación más avanzada, podrías filtrar por alerta específica
      _navegarAAtenderAlertas();
    }
  }

  String _formatearFecha(String? fechaString) {
    if (fechaString == null) return 'Fecha no disponible';

    try {
      DateTime fecha = DateTime.parse(fechaString);
      DateTime ahora = DateTime.now();
      Duration diferencia = ahora.difference(fecha);

      if (diferencia.inMinutes < 1) {
        return 'Hace unos momentos';
      } else if (diferencia.inHours < 1) {
        return 'Hace ${diferencia.inMinutes} min';
      } else if (diferencia.inDays < 1) {
        return 'Hace ${diferencia.inHours} horas';
      } else {
        return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return fechaString.substring(0, 19).replaceAll('T', ' ');
    }
  }

  IconData _getIconoTipo(String? tipo) {
    switch (tipo) {
      case 'alerta_creada':
        return Icons.add_alert;
      case 'alerta_actualizada':
        return Icons.update;
      case 'alerta_atendida':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorTipo(String? tipo) {
    switch (tipo) {
      case 'alerta_creada':
        return Colors.red;
      case 'alerta_actualizada':
        return Colors.orange;
      case 'alerta_atendida':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  bool _esNotificacionLeida(Map<String, dynamic> notificacion) {
    if (currentUserId == null) return false;

    List<dynamic> leidaPor = notificacion['leidaPor'] ?? [];
    return leidaPor.contains(currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🚨 Notificaciones de Alertas'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarNotificaciones,
            tooltip: 'Actualizar notificaciones',
          ),
          if (userRole == 'policia')
            IconButton(
              icon: Icon(Icons.list_alt),
              onPressed: _navegarAAtenderAlertas,
              tooltip: 'Ver todas las alertas',
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando notificaciones...'),
                ],
              ),
            )
          : _notificaciones.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _cargarNotificaciones,
                  child: ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: _notificaciones.length,
                    itemBuilder: (context, index) {
                      final notificacion = _notificaciones[index];
                      return _buildNotificationCard(notificacion);
                    },
                  ),
                ),
      floatingActionButton: userRole == 'policia'
          ? FloatingActionButton.extended(
              onPressed: _navegarAAtenderAlertas,
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              icon: Icon(Icons.assignment),
              label: Text('Atender Alertas'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No hay notificaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            userRole == 'policia'
                ? 'Las nuevas alertas aparecerán aquí'
                : 'No tienes notificaciones pendientes',
            style: TextStyle(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (userRole == 'policia') ...[
            SizedBox(height: 24),
            // Botón ocultado - funcionalidad duplicada con FloatingActionButton
            // ElevatedButton.icon(
            //   onPressed: _navegarAAtenderAlertas,
            //   icon: Icon(Icons.assignment),
            //   label: Text('Ver Alertas Pendientes'),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.blue[700],
            //     foregroundColor: Colors.white,
            //   ),
            // ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notificacion) {
    final bool esLeida = _esNotificacionLeida(notificacion);
    final String tipo = notificacion['tipo'] ?? 'alerta_creada';
    final String mensaje =
        notificacion['mensaje'] ?? 'Notificación sin mensaje';
    final String fecha = _formatearFecha(notificacion['createdAt']);

    // Información de la alerta asociada
    final alerta = notificacion['alerta'];
    final statusAlerta =
        alerta != null ? alerta['status'] ?? 'desconocido' : 'sin alerta';

    return Card(
      elevation: esLeida ? 1 : 4,
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: esLeida ? Colors.grey[100] : Colors.white,
      child: InkWell(
        onTap: () => _navegarAAlertaEspecifica(notificacion['alerta']),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono de tipo de notificación
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getColorTipo(tipo).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getIconoTipo(tipo),
                  color: _getColorTipo(tipo),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),

              // Contenido de la notificación
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título con estado de lectura
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mensaje,
                            style: TextStyle(
                              fontWeight:
                                  esLeida ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                              color:
                                  esLeida ? Colors.grey[700] : Colors.black87,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!esLeida)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),

                    // Estado de la alerta
                    if (alerta != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 12, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text(
                              'Estado: ${statusAlerta.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Información adicional
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          fecha,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Spacer(),
                        _buildTipoChip(tipo),
                      ],
                    ),
                  ],
                ),
              ),

              // Botón de acción
              Column(
                children: [
                  if (!esLeida)
                    IconButton(
                      icon: Icon(
                        Icons.mark_email_read,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      onPressed: () => _marcarComoLeida(notificacion['_id']),
                      tooltip: 'Marcar como leída',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  if (userRole == 'policia')
                    IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.blue[700],
                        size: 16,
                      ),
                      onPressed: () =>
                          _navegarAAlertaEspecifica(notificacion['alerta']),
                      tooltip: 'Ver alerta',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipoChip(String tipo) {
    String label;
    Color color;

    switch (tipo) {
      case 'alerta_creada':
        label = 'NUEVA';
        color = Colors.red;
        break;
      case 'alerta_actualizada':
        label = 'ACTUALIZADA';
        color = Colors.orange;
        break;
      case 'alerta_atendida':
        label = 'ATENDIDA';
        color = Colors.green;
        break;
      default:
        label = 'NOTIF';
        color = Colors.blue;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

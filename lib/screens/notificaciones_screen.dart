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
    print('👤 ID de usuario cargado desde SharedPreferences: $currentUserId');
  }

  Future<void> _cargarNotificaciones() async {
    try {
      final notificaciones =
          await _notificationService.getUltimasNotificaciones();
      setState(() {
        _notificaciones = notificaciones;
        _loading = false;
      });
    } catch (e) {
      print(e);
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _marcarComoLeida(String id) async {
    if (currentUserId == null) {
      print('❌ Error: userId no disponible');
      return;
    }

    try {
      await _notificationService.marcarComoLeida(id, currentUserId!);
      print('✅ Notificación marcada como leída por $currentUserId');
      _cargarNotificaciones(); // refrescar lista
    } catch (e) {
      print('❌ Error al marcar como leída: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notificaciones')),
      body:
          _loading
              ? Center(child: CircularProgressIndicator())
              : _notificaciones.isEmpty
              ? Center(child: Text('No hay notificaciones disponibles.'))
              : RefreshIndicator(
                onRefresh: _cargarNotificaciones,
                child: ListView.builder(
                  itemCount: _notificaciones.length,
                  itemBuilder: (context, index) {
                    final noti = _notificaciones[index];
                    return Card(
                      child: ListTile(
                        title: Text(noti['mensaje'] ?? ''),
                        subtitle: Text(
                          'Fecha: ${noti['createdAt']?.substring(0, 19).replaceAll('T', ' ') ?? ''}',
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.check_circle, color: Colors.green),
                          tooltip: 'Marcar como leída',
                          onPressed: () => _marcarComoLeida(noti['_id']),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

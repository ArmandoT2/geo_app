import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/contacto_service.dart';

class NotificationBadge extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const NotificationBadge({Key? key, required this.child, this.onTap})
    : super(key: key);

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _contadorNotificaciones = 0;
  Timer? _refreshTimer;
  final ContactoService _contactoService = ContactoService();

  @override
  void initState() {
    super.initState();
    _cargarContadorNotificaciones();
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
        _cargarContadorNotificaciones();
      }
    });
  }

  Future<void> _cargarContadorNotificaciones() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

    } catch (e) {
      // Silenciar errores para no mostrar mensajes constantemente
      print('Error al cargar contador de notificaciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        children: [
          widget.child,
          if (_contadorNotificaciones > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  _contadorNotificaciones > 99
                      ? '99+'
                      : _contadorNotificaciones.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

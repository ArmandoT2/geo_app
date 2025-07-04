import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/notification_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _rol;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final rol = prefs.getString('rol'); // Leemos el rol

    if (email == null || email.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() {
        _rol = rol;
      });
    }
  }

  void _navigateTo(String route) {
    Navigator.pushNamed(context, route);
  }

  void _navigateToCrearAlerta() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    Navigator.pushNamed(context, '/crear-alerta', arguments: userId);
  }

  Widget _buildMenuCard(String title, IconData icon, [VoidCallback? onTap]) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 30, color: Theme.of(context).primaryColor),
              const SizedBox(width: 20),
              Text(title, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuByRole() {
    switch (_rol) {
      case 'administrador':
        return [
          _buildMenuCard(
            'Gestión de Usuarios',
            Icons.group,
            () => _navigateTo('/gestion-usuarios'),
          ),
          _buildMenuCard(
            'Gestión de Alertas',
            Icons.warning_rounded,
            () => _navigateTo('/gestion-alertas'),
          ),
        ];
      case 'policia':
        return [
          _buildMenuCard(
            'Atención de Alertas',
            Icons.notifications_active,
            () => _navigateTo('/atender-alerta'),
          ),
        ];
      case 'ciudadano':
      case 'cliente': // Compatibilidad con usuarios existentes
        return [
          _buildMenuCard(
            'Creación de Alertas',
            Icons.add_alert,
            _navigateToCrearAlerta,
          ),
          _buildMenuCard(
            'Mis Contactos',
            Icons.contacts,
            () => _navigateTo('/contactos'),
          ),
          _buildMenuCard(
            'Actualizar Datos',
            Icons.person_outline,
            () => _navigateTo('/actualizar-datos'),
          ),
          NotificationBadge(
            onTap: () => _navigateTo('/notificaciones'),
            child: _buildMenuCard(
              'Notificaciones',
              Icons.notifications,
              () => _navigateTo('/notificaciones'),
            ),
          ),
        ];
      default:
        return [const Center(child: Text("Rol no reconocido"))];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body:
          _rol == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Image.asset(
                      'assets/images/logoApp.jpeg',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ..._buildMenuByRole(),
                ],
              ),
    );
  }
}

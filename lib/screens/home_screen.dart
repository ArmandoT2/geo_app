import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');

    if (email == null || email.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _navigateTo(String route) {
    Navigator.pushNamed(context, route);
  }

  // Función especial para navegar a crear alerta y pasar el userId
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
              await prefs.remove('email');
              await prefs.remove('userId'); // mejor limpiar también el userId
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Column(
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
          _buildMenuCard(
            'Gestión de Usuarios',
            Icons.group,
            () => _navigateTo('/gestion-usuarios'),
          ),
          _buildMenuCard(
            'Creación de Alertas',
            Icons.add_alert,
            _navigateToCrearAlerta,
          ),
          _buildMenuCard(
            'Atención de Alertas',
            Icons.notifications_active,
            () => _navigateTo('/atender-alerta'),
          ),
        ],
      ),
    );
  }
}

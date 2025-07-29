import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ReportesAlertasScreen extends StatefulWidget {
  @override
  _ReportesAlertasScreenState createState() => _ReportesAlertasScreenState();
}

class _ReportesAlertasScreenState extends State<ReportesAlertasScreen> {
  List<dynamic> _alertas = [];
  bool _loading = true;

  // Filtros
  String _filtroEstado = 'Todos';
  String _filtroFecha = 'Todos';
  String _filtroUsuario = 'Todos';
  String _filtroGenero = 'Todos';

  final List<String> _estados = [
    'Todos',
    'pendiente',
    'en camino',
    'atendida',
    'cancelada',
  ];
  final List<String> _rangosFecha = ['Todos', 'Últimos 7 días', 'Último mes'];
  final List<String> _generos = ['Todos', 'masculino', 'femenino'];
  List<String> _usuarios = ['Todos'];
  Map<String, Map<String, dynamic>> _usuariosInfo = {};

  @override
  void initState() {
    super.initState();
    _obtenerAlertas();
  }

  Future<void> _obtenerAlertas() async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.alertasUrl),
      );

      print('📥 Código respuesta: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final alertas = data['alertas'];

        // Extraer usuarios únicos con información completa
        final Map<String, Map<String, dynamic>> usuariosMap = {};

        for (var alerta in alertas) {
          final usuarioCreador = alerta['usuarioCreador'];
          if (usuarioCreador != null) {
            String usuarioId;
            String usuarioNombre = 'Usuario';
            String usuarioEmail = '';

            // Si es un objeto con información completa
            if (usuarioCreador is Map) {
              usuarioId = usuarioCreador['_id']?.toString() ??
                  usuarioCreador.toString();
              usuarioNombre = usuarioCreador['nombre'] ?? 'Usuario';
              usuarioEmail = usuarioCreador['email'] ?? '';
            }
            // Si es directamente un ID string
            else {
              usuarioId = usuarioCreador.toString();
            }

            // Almacenar información del usuario
            if (!usuariosMap.containsKey(usuarioId)) {
              usuariosMap[usuarioId] = {
                'id': usuarioId,
                'nombre': usuarioNombre,
                'email': usuarioEmail,
              };
            }
          }
        }

        setState(() {
          _alertas = alertas;
          _usuarios = ['Todos', ...usuariosMap.keys.toList()];
          _usuariosInfo = usuariosMap;
          // Asegurar que el filtro actual esté en la lista
          if (!_usuarios.contains(_filtroUsuario)) {
            _filtroUsuario = 'Todos';
          }
          _loading = false;
        });
      } else {
        throw Exception('Error al obtener alertas');
      }
    } catch (e) {
      print('❌ Error al cargar alertas: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  List<dynamic> _filtrarAlertas() {
    return _alertas.where((alerta) {
      // Estado
      if (_filtroEstado != 'Todos' && alerta['status'] != _filtroEstado)
        return false;

      // Usuario
      if (_filtroUsuario != 'Todos') {
        final usuarioCreador = alerta['usuarioCreador'];
        String usuarioId;

        if (usuarioCreador is Map && usuarioCreador.containsKey('_id')) {
          usuarioId = usuarioCreador['_id'].toString();
        } else if (usuarioCreador is String) {
          usuarioId = usuarioCreador;
        } else {
          usuarioId = usuarioCreador?.toString() ?? '';
        }

        if (usuarioId != _filtroUsuario) return false;
      }

      // Fecha
      if (_filtroFecha != 'Todos') {
        DateTime fechaAlerta =
            DateTime.tryParse(alerta['fechaHora'] ?? '') ?? DateTime.now();
        DateTime ahora = DateTime.now();

        if (_filtroFecha == 'Últimos 7 días' &&
            fechaAlerta.isBefore(ahora.subtract(Duration(days: 7)))) {
          return false;
        }

        if (_filtroFecha == 'Último mes' &&
            fechaAlerta.isBefore(
              DateTime(ahora.year, ahora.month - 1, ahora.day),
            )) {
          return false;
        }
      }

      // Género del usuario
      if (_filtroGenero != 'Todos') {
        final creador = alerta['usuarioCreador'];
        if (creador is Map && creador.containsKey('genero')) {
          if (creador['genero'] != _filtroGenero) return false;
        } else {
          // Si no tiene datos de género, solo filtramos si el filtro no es "Todos"
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildUsuarioDropdownItem(String usuario) {
    if (usuario == 'Todos') {
      return Row(
        children: [
          Icon(Icons.people, color: Colors.blue, size: 20),
          SizedBox(width: 8),
          Text(
            'Todos los usuarios',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      );
    }

    final usuarioInfo = _usuariosInfo[usuario];
    final nombre = usuarioInfo?['nombre'] ?? 'Usuario';
    final email = usuarioInfo?['email'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.person, color: Colors.grey.shade600, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                nombre,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (email.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: 26),
            child: Text(
              email,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (email.isEmpty)
          Padding(
            padding: EdgeInsets.only(left: 26),
            child: Text(
              'ID: ${usuario.length > 15 ? usuario.substring(0, 15) + '...' : usuario}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildAlertaCard(dynamic alerta) {
    final creador = alerta['usuarioCreador'];
    final genero =
        (creador is Map) ? creador['genero'] ?? 'No definido' : 'No definido';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded),
        title: Text(alerta['detalle'] ?? 'Sin detalle'),
        subtitle: Text(
          'Dirección: ${alerta['direccion'] ?? 'Desconocida'}\n'
          'Estado: ${alerta['status']}\n'
          'Género creador: $genero',
        ),
        trailing: Text(
          alerta['fechaHora']?.substring(0, 10) ?? '',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtros de Búsqueda',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Estado',
                  value: _filtroEstado,
                  items: _estados,
                  onChanged: (value) => setState(() => _filtroEstado = value!),
                  icon: Icons.flag,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: 'Período',
                  value: _filtroFecha,
                  items: _rangosFecha,
                  onChanged: (value) => setState(() => _filtroFecha = value!),
                  icon: Icons.calendar_today,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: Colors.blue, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Usuario',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _filtroUsuario,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.blue),
                          items: _usuarios.map((usuario) {
                            return DropdownMenuItem(
                              value: usuario,
                              child: _buildUsuarioDropdownItem(usuario),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null && _usuarios.contains(value)) {
                              setState(() => _filtroUsuario = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: 'Género',
                  value: _filtroGenero,
                  items: _generos,
                  onChanged: (value) => setState(() => _filtroGenero = value!),
                  icon: Icons.person_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 16),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              icon: Icon(Icons.arrow_drop_down, color: Colors.blue),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    item == 'Todos' ? 'Todos' : item,
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Reporte de Alertas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando reportes...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _alertas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hay alertas registradas',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Las alertas aparecerán aquí cuando se registren',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildFiltros(),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _obtenerAlertas,
                        color: Colors.blue,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtrarAlertas().length,
                          itemBuilder: (context, index) =>
                              _buildAlertaCard(_filtrarAlertas()[index]),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

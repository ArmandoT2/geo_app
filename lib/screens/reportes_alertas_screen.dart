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

        // Debug: imprimir primera alerta para entender la estructura
        if (alertas.isNotEmpty) {
          print('📋 Estructura de primera alerta: ${alertas[0]}');
          if (alertas[0]['usuarioCreador'] != null) {
            print(
                '👤 Estructura de usuarioCreador: ${alertas[0]['usuarioCreador']}');
          }
        }

        // Extraer usuarios únicos y obtener información completa
        final Map<String, Map<String, dynamic>> usuariosMap = {};
        final Set<String> usuarioIds = {};

        // Primero, recopilar todos los IDs de usuarios únicos
        for (var alerta in alertas) {
          final usuarioCreador = alerta['usuarioCreador'];
          if (usuarioCreador != null) {
            String usuarioId;

            if (usuarioCreador is Map) {
              usuarioId = usuarioCreador['_id']?.toString() ??
                  usuarioCreador.toString();
            } else {
              usuarioId = usuarioCreador.toString();
            }

            if (usuarioId.isNotEmpty) {
              usuarioIds.add(usuarioId);
            }
          }
        }

        // Ahora obtener información de usuarios desde el endpoint de usuarios
        await _obtenerInformacionUsuarios(usuarioIds.toList(), usuariosMap);

        // También procesar información de usuarios que venga en las alertas
        for (var alerta in alertas) {
          final usuarioCreador = alerta['usuarioCreador'];
          if (usuarioCreador != null && usuarioCreador is Map) {
            String usuarioId =
                usuarioCreador['_id']?.toString() ?? usuarioCreador.toString();

            // Solo usar esta información si no tenemos mejor información del endpoint de usuarios
            if (!usuariosMap.containsKey(usuarioId)) {
              String usuarioNombre = usuarioCreador['fullName'] ??
                  usuarioCreador['nombre'] ??
                  usuarioCreador['username'] ??
                  'Usuario ${usuarioId.substring(0, 8)}';
              String usuarioEmail = usuarioCreador['email'] ?? '';

              usuariosMap[usuarioId] = {
                'id': usuarioId,
                'nombre': usuarioNombre,
                'email': usuarioEmail,
              };

              print(
                  '👤 Usuario de alerta: ID=$usuarioId, Nombre=$usuarioNombre');
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

  Future<void> _obtenerInformacionUsuarios(List<String> usuarioIds,
      Map<String, Map<String, dynamic>> usuariosMap) async {
    try {
      // Hacer llamada al endpoint de usuarios para obtener información completa
      final response = await http.get(
        Uri.parse(AppConfig.usuariosUrl),
      );

      if (response.statusCode == 200) {
        final usuarios = json.decode(response.body);

        if (usuarios is List) {
          for (var usuario in usuarios) {
            String usuarioId = usuario['_id']?.toString() ?? '';

            if (usuarioIds.contains(usuarioId)) {
              String usuarioNombre = usuario['fullName'] ??
                  usuario['nombre'] ??
                  usuario['username'] ??
                  'Usuario ${usuarioId.substring(0, 8)}';
              String usuarioEmail = usuario['email'] ?? '';

              usuariosMap[usuarioId] = {
                'id': usuarioId,
                'nombre': usuarioNombre,
                'email': usuarioEmail,
              };

              print(
                  '👤 Usuario completo: ID=$usuarioId, Nombre=$usuarioNombre, Email=$usuarioEmail');
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error al obtener información de usuarios: $e');
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people, color: Colors.blue, size: 18),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Todos los usuarios',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final usuarioInfo = _usuariosInfo[usuario];
    String nombre;

    if (usuarioInfo != null &&
        usuarioInfo['nombre'] != null &&
        usuarioInfo['nombre'] != 'Usuario') {
      nombre = usuarioInfo['nombre'];
    } else {
      // Si no hay información del usuario, usar el ID truncado
      nombre =
          'Usuario ${usuario.length > 8 ? usuario.substring(0, 8) : usuario}';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person, color: Colors.grey.shade600, size: 16),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            nombre.length > 20 ? '${nombre.substring(0, 17)}...' : nombre,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
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
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(
          Icons.warning_amber_rounded,
          size: 20,
          color: _getStatusColor(alerta['status']),
        ),
        title: Text(
          alerta['detalle'] ?? 'Sin detalle',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dir: ${_truncateText(alerta['direccion'] ?? 'Desconocida', 25)}',
              style: TextStyle(fontSize: 12),
            ),
            Row(
              children: [
                Text(
                  'Estado: ${alerta['status']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(alerta['status']),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'G: $genero',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        trailing: Text(
          alerta['fechaHora']?.substring(0, 10) ?? '',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  String _truncateText(String text, int maxLength) {
    return text.length > maxLength
        ? '${text.substring(0, maxLength)}...'
        : text;
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pendiente':
        return Colors.orange;
      case 'en camino':
        return Colors.blue;
      case 'atendida':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFiltros() {
    return Container(
      padding: EdgeInsets.all(12),
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
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 10),
          // Primera fila: Estado y Período
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
              SizedBox(width: 8),
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
          SizedBox(height: 8),
          // Segunda fila: Usuario y Género (versión compacta)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildUsuarioDropdown(),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 2,
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

  Widget _buildUsuarioDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.blue, size: 14),
              SizedBox(width: 4),
              Text(
                'Usuario',
                style: TextStyle(
                  fontSize: 11,
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
              icon: Icon(Icons.arrow_drop_down, color: Colors.blue, size: 18),
              isDense: true,
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 14),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
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
              icon: Icon(Icons.arrow_drop_down, color: Colors.blue, size: 18),
              isDense: true,
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    item == 'Todos' ? 'Todos' : item,
                    style: TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
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
                      padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: _buildFiltros(),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _obtenerAlertas,
                        color: Colors.blue,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 12),
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

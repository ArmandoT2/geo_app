import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();
    _obtenerAlertas();
  }

  Future<void> _obtenerAlertas() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/alertas'),
      );

      print('📥 Código respuesta: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final alertas = data['alertas'];

        // Extraer usuarios únicos por ID
        final creadosPor =
            alertas
                .map((a) => a['usuarioCreador'])
                .where((id) => id != null)
                .toSet()
                .toList();

        setState(() {
          _alertas = alertas;
          _usuarios = ['Todos', ...creadosPor.map((e) => e.toString())];
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
      if (_filtroUsuario != 'Todos' &&
          alerta['usuarioCreador'] != _filtroUsuario)
        return false;

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
          return false; // si no tiene género, no lo mostramos al filtrar
        }
      }

      return true;
    }).toList();
  }

  Widget _buildAlertaCard(dynamic alerta) {
    final creador = alerta['usuarioCreador'];
    final genero =
        (creador is Map) ? creador['genero'] ?? 'No definido' : 'No definido';
    final creadorId =
        (creador is Map) ? creador['_id'] ?? '' : creador?.toString();

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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _filtroEstado,
                items:
                    _estados.map((estado) {
                      return DropdownMenuItem(
                        value: estado,
                        child: Text('Estado: $estado'),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _filtroEstado = value!),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _filtroFecha,
                items:
                    _rangosFecha.map((rango) {
                      return DropdownMenuItem(
                        value: rango,
                        child: Text('Fecha: $rango'),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _filtroFecha = value!),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _filtroUsuario,
                items:
                    _usuarios.map((usuario) {
                      return DropdownMenuItem(
                        value: usuario,
                        child: Text(
                          usuario == 'Todos'
                              ? 'Todos los usuarios'
                              : 'Usuario ID: $usuario',
                        ),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _filtroUsuario = value!),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _filtroGenero,
                items:
                    _generos.map((genero) {
                      return DropdownMenuItem(
                        value: genero,
                        child: Text(
                          genero == 'Todos'
                              ? 'Todos los géneros'
                              : 'Género: $genero',
                        ),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _filtroGenero = value!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reporte de Alertas')),
      body:
          _loading
              ? Center(child: CircularProgressIndicator())
              : _alertas.isEmpty
              ? Center(child: Text('No hay alertas registradas.'))
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildFiltros(),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _obtenerAlertas,
                      child: ListView.builder(
                        itemCount: _filtrarAlertas().length,
                        itemBuilder:
                            (context, index) =>
                                _buildAlertaCard(_filtrarAlertas()[index]),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

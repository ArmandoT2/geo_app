import 'package:flutter/material.dart';

import '../models/alerta_model.dart';
import '../services/alerta_service.dart';
import 'alerta_admin_form_screen.dart';

class GestionAlertasScreen extends StatefulWidget {
  const GestionAlertasScreen({super.key});

  @override
  State<GestionAlertasScreen> createState() => _GestionAlertasScreenState();
}

class _GestionAlertasScreenState extends State<GestionAlertasScreen> {
  final AlertaService _alertaService = AlertaService();
  List<Alerta> _alertas = [];
  bool _isLoading = true;
  String _filtroEstado = 'todas'; // todas, activas, ocultas, atendidas

  @override
  void initState() {
    super.initState();
    _cargarAlertas();
  }

  Future<void> _cargarAlertas() async {
    setState(() => _isLoading = true);
    try {
      final alertas = await _alertaService.obtenerTodasLasAlertas();
      setState(() {
        _alertas = alertas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar alertas: $e');
    }
  }

  List<Alerta> _alertasFiltradas() {
    switch (_filtroEstado) {
      case 'activas':
        return _alertas
            .where((a) => a.status == 'pendiente' && a.visible == true)
            .toList();
      case 'ocultas':
        return _alertas.where((a) => a.visible == false).toList();
      case 'atendidas':
        return _alertas.where((a) => a.status == 'atendida').toList();
      default:
        return _alertas;
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  Future<void> _ocultarAlerta(Alerta alerta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar acción'),
        content: Text(
          'Esta acción ocultará la alerta de la vista del ciudadano.\n\n'
          'La alerta permanecerá en la base de datos para reportes.\n\n'
          '¿Está seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Ocultar Alerta'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _alertaService.ocultarAlerta(alerta.id);
        _mostrarExito('Alerta ocultada correctamente');
        _cargarAlertas();
      } catch (e) {
        _mostrarError('Error al ocultar alerta: $e');
      }
    }
  }

  Future<void> _restaurarAlerta(Alerta alerta) async {
    try {
      await _alertaService.restaurarAlerta(alerta.id);
      _mostrarExito('Alerta restaurada correctamente');
      _cargarAlertas();
    } catch (e) {
      _mostrarError('Error al restaurar alerta: $e');
    }
  }

  void _editarAlerta(Alerta alerta) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertaAdminFormScreen(alerta: alerta),
      ),
    ).then((_) => _cargarAlertas());
  }

  void _verDetalles(Alerta alerta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles de Alerta #${alerta.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetalle('ID:', alerta.id),
              _buildDetalle('Dirección:', alerta.direccionCompleta),
              _buildDetalle('Estado:', alerta.status),
              _buildDetalle('Fecha:', alerta.fechaHora.toString()),
              if (alerta.ciudad != null && alerta.ciudad!.isNotEmpty)
                _buildDetalle('Ciudad:', alerta.ciudad!),
              if (alerta.barrio != null && alerta.barrio!.isNotEmpty)
                _buildDetalle('Barrio:', alerta.barrio!),
              _buildDetalle(
                'Coordenadas:',
                '${alerta.lat?.toStringAsFixed(4) ?? 'N/A'}, ${alerta.lng?.toStringAsFixed(4) ?? 'N/A'}',
              ),
              _buildDetalle('Descripción:', alerta.detalle),
              _buildDetalle('Ciudadano:', alerta.usuarioCreador),
              _buildDetalle('Visible:', alerta.visible ? 'Sí' : 'No'),
              if (alerta.atendidoPor != null)
                _buildDetalle('Atendida por:', alerta.atendidoPor!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalle(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              etiqueta,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.red;
      case 'en_atencion':
        return Colors.orange;
      case 'atendida':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertasFiltradas = _alertasFiltradas();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Alertas'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filtroEstado = value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'todas',
                child: Text('Todas las alertas'),
              ),
              PopupMenuItem(
                value: 'activas',
                child: Text('Alertas activas'),
              ),
              PopupMenuItem(
                value: 'ocultas',
                child: Text('Alertas ocultas'),
              ),
              PopupMenuItem(
                value: 'atendidas',
                child: Text('Alertas atendidas'),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Filtro: $_filtroEstado'),
                Icon(Icons.filter_list),
                SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : alertasFiltradas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No hay alertas para mostrar',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarAlertas,
                  child: ListView.builder(
                    itemCount: alertasFiltradas.length,
                    itemBuilder: (context, index) {
                      final alerta = alertasFiltradas[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getColorEstado(alerta.status),
                            child: Icon(Icons.warning, color: Colors.white),
                          ),
                          title: Text(
                            alerta.direccionCorta,
                            style: TextStyle(
                              decoration: alerta.visible
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Estado: ${alerta.status}'),
                              Text('Detalle: ${alerta.detalle}'),
                              Text(
                                'Fecha: ${alerta.fechaHora.toString().substring(0, 16)}',
                              ),
                              if (!alerta.visible)
                                Text(
                                  'OCULTA',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'ver':
                                  _verDetalles(alerta);
                                  break;
                                case 'editar':
                                  _editarAlerta(alerta);
                                  break;
                                case 'ocultar':
                                  _ocultarAlerta(alerta);
                                  break;
                                case 'restaurar':
                                  _restaurarAlerta(alerta);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'ver',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility),
                                    SizedBox(width: 8),
                                    Text('Ver detalles'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'editar',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              if (alerta.visible)
                                PopupMenuItem(
                                  value: 'ocultar',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.visibility_off,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Ocultar del ciudadano'),
                                    ],
                                  ),
                                ),
                              if (!alerta.visible)
                                PopupMenuItem(
                                  value: 'restaurar',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.restore,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Restaurar'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

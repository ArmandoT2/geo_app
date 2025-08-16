import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alerta_model.dart';
import '../services/alerta_service.dart';

class AlertasAtendidasScreen extends StatefulWidget {
  const AlertasAtendidasScreen({super.key});

  @override
  State<AlertasAtendidasScreen> createState() => _AlertasAtendidasScreenState();
}

class _AlertasAtendidasScreenState extends State<AlertasAtendidasScreen> {
  late Future<List<Alerta>> _alertasAtendidasFuture;
  final Map<String, String> _nombresUsuarios = {};

  @override
  void initState() {
    super.initState();
    _cargarAlertasAtendidas();
  }

  void _cargarAlertasAtendidas() {
    _alertasAtendidasFuture = _obtenerAlertasAtendidas();
  }

  Future<List<Alerta>> _obtenerAlertasAtendidas() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final policiaId = prefs.getString('userId') ?? '';

      if (policiaId.isEmpty) {
        print('❌ ID de policía no encontrado en preferencias');
        return [];
      }

      print('🔍 INICIANDO BUSQUEDA DE ALERTAS ATENDIDAS');
      print('🔍 ID de policía: $policiaId');
      print('🔍 Llamando al servicio...');

      // Usar el servicio existente para obtener alertas atendidas por este policía
      final alertas =
          await AlertaService().obtenerAlertasAtendidasPorPolicia(policiaId);

      print('✅ RESULTADO: ${alertas.length} alertas atendidas obtenidas');

      if (alertas.isNotEmpty) {
        print('📋 ALERTAS ENCONTRADAS:');
        for (int i = 0; i < alertas.length; i++) {
          print('   Alerta ${i + 1}: ${alertas[i].id} - ${alertas[i].detalle}');
        }
      } else {
        print('⚠️ NO SE ENCONTRARON ALERTAS ATENDIDAS');
      }

      // Cargar nombres de usuarios creadores
      for (var alerta in alertas) {
        if (!_nombresUsuarios.containsKey(alerta.usuarioCreador)) {
          try {
            final nombre = await _obtenerNombreUsuario(alerta.usuarioCreador);
            _nombresUsuarios[alerta.usuarioCreador] = nombre;
          } catch (e) {
            print(
                'Error al obtener nombre de usuario ${alerta.usuarioCreador}: $e');
            _nombresUsuarios[alerta.usuarioCreador] = 'Usuario desconocido';
          }
        }
      }

      return alertas;
    } catch (e) {
      print('❌ Error al obtener alertas atendidas: $e');
      return [];
    }
  }

  Future<String> _obtenerNombreUsuario(String usuarioId) async {
    try {
      // Aquí podrías usar un servicio específico para obtener el nombre del usuario
      // Por ahora, retornamos un placeholder
      return 'Usuario $usuarioId';
    } catch (e) {
      return 'Usuario desconocido';
    }
  }

  Color _getColorByStatus(String status) {
    switch (status.toLowerCase()) {
      case 'atendida':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatearFecha(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  Widget _buildAlertaCard(Alerta alerta) {
    final nombreUsuario =
        _nombresUsuarios[alerta.usuarioCreador] ?? 'Cargando...';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _mostrarDetalleAlerta(alerta),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con estado y fecha
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 2,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getColorByStatus(alerta.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          alerta.status.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      flex: 3,
                      child: Text(
                        _formatearFecha(alerta.fechaHora),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Detalle de la alerta
                Container(
                  width: double.infinity,
                  child: Text(
                    alerta.detalle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: 8),

                // Dirección
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alerta.direccionCompleta,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Usuario creador
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Reportado por: $nombreUsuario',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Indicador de detalles de atención si existen
                if (alerta.detallesAtencion != null &&
                    alerta.detallesAtencion!.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.note_alt, size: 16, color: Colors.blue[600]),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Detalles de atención disponibles',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleAlerta(Alerta alerta) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Detalle de Alerta Atendida',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Estado:', alerta.status.toUpperCase()),
                  _buildDetailRow('Fecha:', _formatearFecha(alerta.fechaHora)),
                  _buildDetailRow('Detalle:', alerta.detalle),
                  _buildDetailRow('Dirección:', alerta.direccionCompleta),
                  _buildDetailRow('Reportado por:',
                      _nombresUsuarios[alerta.usuarioCreador] ?? 'Desconocido'),
                  if (alerta.detallesAtencion != null &&
                      alerta.detallesAtencion!.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Detalles de Atención:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue[700]),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        alerta.detallesAtencion!,
                        style: TextStyle(fontSize: 14),
                        softWrap: true,
                      ),
                    ),
                  ],
                  if (alerta.evidencia != null &&
                      alerta.evidencia!.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Evidencia:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${alerta.evidencia!.length} archivo(s) de evidencia',
                      style: TextStyle(color: Colors.green[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 2),
          Container(
            width: double.infinity,
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Alertas Atendidas'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _cargarAlertasAtendidas();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Alerta>>(
        future: _alertasAtendidasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando alertas atendidas...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error al cargar alertas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _cargarAlertasAtendidas();
                      });
                    },
                    child: Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final alertas = snapshot.data ?? [];

          if (alertas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No has atendido alertas aún',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Las alertas que atiendas aparecerán aquí',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _cargarAlertasAtendidas();
              });
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: alertas.length,
                  itemBuilder: (context, index) {
                    return Container(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: _buildAlertaCard(alertas[index]),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

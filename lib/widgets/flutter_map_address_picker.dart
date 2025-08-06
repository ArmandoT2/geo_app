import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../services/location_service.dart';

class FlutterMapAddressPicker extends StatefulWidget {
  final String initialAddress;
  final Function(String) onAddressSelected;

  const FlutterMapAddressPicker({
    super.key,
    required this.initialAddress,
    required this.onAddressSelected,
  });

  @override
  State<FlutterMapAddressPicker> createState() =>
      _FlutterMapAddressPickerState();
}

class _FlutterMapAddressPickerState extends State<FlutterMapAddressPicker> {
  late TextEditingController _addressController;
  bool _isLoadingLocation = false;
  Map<String, String> _direccionDetallada = {};

  // Variables para el mapa
  LatLng? _currentPosition;
  final MapController _mapController = MapController();

  // Ubicación por defecto (Ecuador - Quito)
  static final LatLng _defaultLocation =
      LatLng(AppConfig.defaultLat, AppConfig.defaultLng);

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
    // NO mostrar marcador inicialmente, solo el mapa centrado en ubicación por defecto
    // _currentPosition permanece null hasta que se obtenga ubicación real
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() => _isLoadingLocation = true);

    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        await _actualizarDireccion(
            LatLng(position.latitude, position.longitude));

        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ubicación actualizada correctamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Usar ubicación por defecto
        await _actualizarDireccion(_defaultLocation);

        // Mostrar mensaje de error si no se puede obtener la ubicación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'No se pudo obtener la ubicación actual. Se usó ubicación por defecto.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');

      // Usar ubicación por defecto en caso de error
      await _actualizarDireccion(_defaultLocation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener la ubicación: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _actualizarDireccion(LatLng position) async {
    setState(() {
      _currentPosition = position;
    });

    // Mover la cámara del mapa a la nueva posición
    _mapController.move(position, 16.0);

    try {
      _direccionDetallada =
          await LocationService.getDetailedAddressFromCoordinates(position);

      final direccionCompleta = _direccionDetallada['direccion_completa'] ??
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      setState(() {
        _addressController.text = direccionCompleta;
      });

      // Informar al widget padre sobre el cambio
      widget.onAddressSelected(direccionCompleta);
    } catch (e) {
      final direccionCoordenadas =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      setState(() {
        _addressController.text = direccionCoordenadas;
      });

      widget.onAddressSelected(direccionCoordenadas);
      print('Error obteniendo dirección: $e');
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo de texto editable
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Dirección',
            hintText: 'Escribe tu dirección o usa tu ubicación actual',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          onChanged: (value) {
            widget.onAddressSelected(value);
          },
        ),

        const SizedBox(height: 12),

        // Botón para obtener ubicación actual
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoadingLocation ? null : _obtenerUbicacionActual,
                icon: _isLoadingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_isLoadingLocation
                    ? 'Obteniendo ubicación...'
                    : 'Usar mi ubicación actual'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Mapa siempre visible
        Container(
          height: 300,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentPosition ?? _defaultLocation,
              zoom: 16,
              onTap: (tapPosition, point) {
                _actualizarDireccion(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.mapTileUrl,
                subdomains: AppConfig.mapSubdomains,
                userAgentPackageName: 'com.example.geo_app',
                retinaMode: true,
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      builder: (ctx) => Container(
                        child: Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(1, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Instrucción para el mapa
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentPosition != null
                      ? 'Toca en el mapa para ajustar la ubicación precisa'
                      : 'Presiona "Usar mi ubicación actual" para ver tu ubicación en el mapa',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Mostrar información detallada si está disponible
        if (_direccionDetallada.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Detalles de ubicación detectada:',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_direccionDetallada['calle']?.isNotEmpty == true)
                  _buildDetailRow('Calle:', _direccionDetallada['calle']!),
                if (_direccionDetallada['barrio']?.isNotEmpty == true)
                  _buildDetailRow('Barrio:', _direccionDetallada['barrio']!),
                if (_direccionDetallada['ciudad']?.isNotEmpty == true)
                  _buildDetailRow('Ciudad:', _direccionDetallada['ciudad']!),
                if (_direccionDetallada['estado']?.isNotEmpty == true)
                  _buildDetailRow(
                      'Estado/Provincia:', _direccionDetallada['estado']!),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Instrucciones
        Text(
          'Puedes usar tu ubicación actual o escribir la dirección manualmente.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

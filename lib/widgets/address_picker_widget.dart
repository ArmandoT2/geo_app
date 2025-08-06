import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';

class AddressPickerWidget extends StatefulWidget {
  final String initialAddress;
  final Function(String) onAddressSelected;

  const AddressPickerWidget({
    super.key,
    required this.initialAddress,
    required this.onAddressSelected,
  });

  @override
  State<AddressPickerWidget> createState() => _AddressPickerWidgetState();
}

class _AddressPickerWidgetState extends State<AddressPickerWidget> {
  late TextEditingController _addressController;
  bool _isLoadingLocation = false;
  Map<String, String> _direccionDetallada = {};

  // Variables para el mapa
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  bool _showMap = false;

  // Ubicación por defecto (Ecuador - Quito)
  static const LatLng _defaultLocation = LatLng(-0.1807, -78.4678);

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
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
        // Guardar la posición actual
        _currentPosition = LatLng(position.latitude, position.longitude);

        // Obtener dirección detallada usando la funcionalidad existente
        _direccionDetallada =
            await LocationService.getDetailedAddressFromCoordinates(position);

        final direccionCompleta =
            _direccionDetallada['direccion_completa'] ?? '';

        // Crear marcador para la ubicación actual
        _markers = {
          Marker(
            markerId: const MarkerId('ubicacion_actual'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: InfoWindow(
              title: 'Mi ubicación actual',
              snippet: direccionCompleta,
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        };

        setState(() {
          _addressController.text = direccionCompleta;
          _showMap = true; // Mostrar el mapa después de obtener la ubicación
        });

        // Mover la cámara del mapa a la ubicación actual
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 16.0,
              ),
            ),
          );
        }

        // Informar al widget padre sobre el cambio
        widget.onAddressSelected(direccionCompleta);

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
        // Mostrar mensaje de error si no se puede obtener la ubicación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo obtener la ubicación actual'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');
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

        // Mostrar el mapa si está disponible
        if (_showMap && _currentPosition != null) ...[
          Container(
            height: 300,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                // Mover la cámara a la ubicación actual cuando se carga el mapa
                if (_currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: _currentPosition!,
                        zoom: 16.0,
                      ),
                    ),
                  );
                }
              },
              initialCameraPosition: CameraPosition(
                target: _currentPosition ?? _defaultLocation,
                zoom: 16.0,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: true,
            ),
          ),
          const SizedBox(height: 8),
        ],

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

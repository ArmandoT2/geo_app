import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';

class LocationService {
  static Future<LocationPermission> _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  static Future<LatLng?> getCurrentLocation() async {
    try {
      final permission = await _checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Permisos de ubicación denegados');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      return null;
    }
  }

  static LatLng getDefaultLocation() {
    return LatLng(AppConfig.defaultLat, AppConfig.defaultLng);
  }

  static Future<LatLng> getCurrentLocationOrDefault() async {
    final location = await getCurrentLocation();
    return location ?? getDefaultLocation();
  }

  static double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Convierte coordenadas en una dirección legible
  static Future<String> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return _formatAddress(place);
      }
    } catch (e) {
      print('Error en geocodificación inversa: $e');
    }

    // Si falla, devolver las coordenadas
    return '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
  }

  /// Formatea la dirección de manera legible
  static String _formatAddress(Placemark place) {
    List<String> addressParts = [];

    // Agregar calle y número
    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }

    // Agregar barrio/subzona
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }

    // Agregar ciudad/localidad
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }

    // Agregar zona administrativa (estado/provincia)
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }

    // Agregar país
    if (place.country != null && place.country!.isNotEmpty) {
      addressParts.add(place.country!);
    }

    return addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'Dirección no disponible';
  }

  /// Obtiene información detallada de la dirección
  static Future<Map<String, String>> getDetailedAddressFromCoordinates(
    LatLng coordinates,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return {
          'calle': place.street ?? '',
          'barrio': place.subLocality ?? '',
          'ciudad': place.locality ?? '',
          'estado': place.administrativeArea ?? '',
          'pais': place.country ?? '',
          'codigo_postal': place.postalCode ?? '',
          'direccion_completa': _formatAddress(place),
        };
      }
    } catch (e) {
      print('Error en geocodificación inversa detallada: $e');
    }

    return {
      'calle': '',
      'barrio': '',
      'ciudad': '',
      'estado': '',
      'pais': '',
      'codigo_postal': '',
      'direccion_completa':
          '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}',
    };
  }
}

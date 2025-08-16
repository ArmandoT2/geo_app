class RutaAtencion {
  final double origenLat;
  final double origenLng;
  final double destinoLat;
  final double destinoLng;

  RutaAtencion({
    required this.origenLat,
    required this.origenLng,
    required this.destinoLat,
    required this.destinoLng,
  });

  factory RutaAtencion.fromJson(Map<String, dynamic> json) {
    return RutaAtencion(
      origenLat: json['origen']?['lat']?.toDouble() ?? 0.0,
      origenLng: json['origen']?['lng']?.toDouble() ?? 0.0,
      destinoLat: json['destino']?['lat']?.toDouble() ?? 0.0,
      destinoLng: json['destino']?['lng']?.toDouble() ?? 0.0,
    );
  }
}

class Alerta {
  final String id;
  final String direccion;
  final String usuarioCreador;
  final String? nombreUsuario; // Nombre completo del usuario
  final DateTime fechaHora;
  final String detalle;
  final String status;
  final String? atendidoPor;
  final String? detallesAtencion; // Detalles de atención del gendarme
  final List<String>? evidencia;
  final RutaAtencion? rutaAtencion;
  final double? lat;
  final double? lng;
  final bool visible; // Nuevo campo para gestión de administrador

  // Nuevos campos para dirección detallada
  final String? calle;
  final String? barrio;
  final String? ciudad;
  final String? estado;
  final String? pais;
  final String? codigoPostal;

  Alerta({
    required this.id,
    required this.direccion,
    required this.usuarioCreador,
    this.nombreUsuario,
    required this.fechaHora,
    required this.detalle,
    required this.status,
    this.atendidoPor,
    this.detallesAtencion,
    this.evidencia,
    this.rutaAtencion,
    this.lat,
    this.lng,
    this.visible = true, // Por defecto visible
    this.calle,
    this.barrio,
    this.ciudad,
    this.estado,
    this.pais,
    this.codigoPostal,
  });

  factory Alerta.fromJson(Map<String, dynamic> json) {
    try {
      // Verificar básicos
      String id = json['_id']?.toString() ?? '';
      String direccion = json['direccion']?.toString() ?? '';

      // usuarioCreador - verificar si es objeto o string
      String usuarioCreador;
      if (json['usuarioCreador'] is String) {
        usuarioCreador = json['usuarioCreador'];
      } else if (json['usuarioCreador'] is Map) {
        usuarioCreador = json['usuarioCreador']['_id']?.toString() ?? '';
      } else {
        usuarioCreador = '';
      }

      DateTime fechaHora = DateTime.parse(json['fechaHora'].toString());
      String detalle = json['detalle']?.toString() ?? '';

      String status = json['status']?.toString() ?? '';

      // evidencia
      List<String>? evidencia;
      try {
        if (json['evidencia'] != null) {
          if (json['evidencia'] is List) {
            evidencia = (json['evidencia'] as List)
                .map((item) => item.toString())
                .toList();
          } else {
            evidencia = [];
          }
        }
      } catch (e) {
        evidencia = [];
      }

      // rutaAtencion
      RutaAtencion? rutaAtencion;
      try {
        if (json['rutaAtencion'] != null && json['rutaAtencion'] is Map) {
          rutaAtencion = RutaAtencion.fromJson(json['rutaAtencion']);
        }
      } catch (e) {
        rutaAtencion = null;
      }

      // ubicacion
      double? lat, lng;
      try {
        if (json['ubicacion'] != null && json['ubicacion'] is Map) {
          lat = _parseDouble(json['ubicacion']['lat']);
          lng = _parseDouble(json['ubicacion']['lng']);
        }
      } catch (e) {
        lat = null;
        lng = null;
      }

      // atendidoPor
      String? atendidoPor;
      try {
        if (json['atendidoPor'] != null) {
          if (json['atendidoPor'] is String) {
            atendidoPor = json['atendidoPor'];
          } else if (json['atendidoPor'] is Map) {
            atendidoPor = json['atendidoPor']['_id']?.toString();
          }
        }
      } catch (e) {
        atendidoPor = null;
      }

      return Alerta(
        id: id,
        direccion: direccion,
        usuarioCreador: usuarioCreador,
        nombreUsuario: json['nombreUsuario']?.toString(),
        fechaHora: fechaHora,
        detalle: detalle,
        status: status,
        atendidoPor: atendidoPor,
        detallesAtencion: json['detallesAtencion']?.toString(),
        evidencia: evidencia,
        rutaAtencion: rutaAtencion,
        lat: lat,
        lng: lng,
        visible: json['visible'] ?? true,
        calle: json['calle']?.toString(),
        barrio: json['barrio']?.toString(),
        ciudad: json['ciudad']?.toString(),
        estado: json['estado']?.toString(),
        pais: json['pais']?.toString(),
        codigoPostal: json['codigoPostal']?.toString(),
      );
    } catch (e) {
      print('Error parseando Alerta desde JSON: $e');
      rethrow;
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'direccion': direccion,
      'usuarioCreador': usuarioCreador,
      'fechaHora': fechaHora.toIso8601String(),
      'detalle': detalle,
      'status': status,
      'atendidoPor': atendidoPor,
      'evidencia': evidencia,
      'visible': visible, // Incluir campo de visibilidad
      'calle': calle,
      'barrio': barrio,
      'ciudad': ciudad,
      'estado': estado,
      'pais': pais,
      'codigoPostal': codigoPostal,
      'rutaAtencion': rutaAtencion != null
          ? {
              'origen': {
                'lat': rutaAtencion!.origenLat,
                'lng': rutaAtencion!.origenLng,
              },
              'destino': {
                'lat': rutaAtencion!.destinoLat,
                'lng': rutaAtencion!.destinoLng,
              },
            }
          : null,
      'ubicacion': {'lat': lat, 'lng': lng},
    };
  }

  /// Obtiene la dirección formateada de manera legible
  String get direccionCompleta {
    List<String> partes = [];

    if (calle != null && calle!.isNotEmpty) partes.add(calle!);
    if (barrio != null && barrio!.isNotEmpty) partes.add(barrio!);
    if (ciudad != null && ciudad!.isNotEmpty) partes.add(ciudad!);
    if (estado != null && estado!.isNotEmpty) partes.add(estado!);

    if (partes.isNotEmpty) {
      return partes.join(', ');
    }

    // Si no hay información de dirección, usar la dirección original o coordenadas
    if (direccion.isNotEmpty && !direccion.contains(',')) {
      return direccion;
    }

    if (lat != null && lng != null) {
      return '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}';
    }

    return 'Ubicación no disponible';
  }

  /// Obtiene la dirección corta (calle y barrio)
  String get direccionCorta {
    List<String> partes = [];

    if (calle != null && calle!.isNotEmpty) partes.add(calle!);
    if (barrio != null && barrio!.isNotEmpty) partes.add(barrio!);

    if (partes.isNotEmpty) {
      return partes.join(', ');
    }

    return direccionCompleta;
  }
}

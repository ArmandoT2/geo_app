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
      origenLat: json['origen']['lat']?.toDouble() ?? 0.0,
      origenLng: json['origen']['lng']?.toDouble() ?? 0.0,
      destinoLat: json['destino']['lat']?.toDouble() ?? 0.0,
      destinoLng: json['destino']['lng']?.toDouble() ?? 0.0,
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
  final List<dynamic>? evidencia;
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
    return Alerta(
      id: json['_id'] ?? '',
      direccion: json['direccion'] ?? '',
      usuarioCreador: json['usuarioCreador'] ?? '',
      nombreUsuario: json['nombreUsuario'],
      fechaHora: DateTime.parse(json['fechaHora']),
      detalle: json['detalle'] ?? '',
      status: json['status'] ?? '',
      atendidoPor: json['atendidoPor'],
      evidencia:
          json['evidencia'] != null
              ? List<dynamic>.from(json['evidencia'])
              : null,
      rutaAtencion:
          json['rutaAtencion'] != null
              ? RutaAtencion.fromJson(json['rutaAtencion'])
              : null,
      lat:
          json['ubicacion']?['lat']?.toDouble() ??
          json['lat']?.toDouble() ??
          json['latitude']?.toDouble(),
      lng:
          json['ubicacion']?['lng']?.toDouble() ??
          json['lng']?.toDouble() ??
          json['longitude']?.toDouble(),
      visible: json['visible'] ?? true, // Campo de visibilidad
      calle: json['calle'],
      barrio: json['barrio'],
      ciudad: json['ciudad'],
      estado: json['estado'],
      pais: json['pais'],
      codigoPostal: json['codigoPostal'],
    );
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
      'rutaAtencion':
          rutaAtencion != null
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

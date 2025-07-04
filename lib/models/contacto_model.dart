class Contacto {
  final String id;
  final String nombre;
  final String apellido;
  final String telefono;
  final String? email;
  final String relacion; // 'familiar', 'amigo', 'emergencia', etc.
  final String usuarioId; // ID del usuario que agregó el contacto
  final bool notificacionesActivas;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  Contacto({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    this.email,
    required this.relacion,
    required this.usuarioId,
    this.notificacionesActivas = true,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  // Nombre completo
  String get nombreCompleto => '$nombre $apellido';

  factory Contacto.fromJson(Map<String, dynamic> json) {
    return Contacto(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      apellido: json['apellido']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      email: json['email']?.toString(),
      relacion: json['relacion']?.toString() ?? 'familiar',
      usuarioId: json['usuario_id']?.toString() ?? '',
      notificacionesActivas:
          json['notificaciones_activas'] == true ||
          json['notificaciones_activas'] == 1,
      fechaCreacion:
          json['fecha_creacion'] != null
              ? DateTime.parse(json['fecha_creacion'])
              : DateTime.now(),
      fechaActualizacion:
          json['fecha_actualizacion'] != null
              ? DateTime.parse(json['fecha_actualizacion'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'telefono': telefono,
      'email': email,
      'relacion': relacion,
      'usuario_id': usuarioId,
      'notificaciones_activas': notificacionesActivas,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }

  Contacto copyWith({
    String? id,
    String? nombre,
    String? apellido,
    String? telefono,
    String? email,
    String? relacion,
    String? usuarioId,
    bool? notificacionesActivas,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return Contacto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      relacion: relacion ?? this.relacion,
      usuarioId: usuarioId ?? this.usuarioId,
      notificacionesActivas:
          notificacionesActivas ?? this.notificacionesActivas,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  @override
  String toString() {
    return 'Contacto{id: $id, nombreCompleto: $nombreCompleto, telefono: $telefono, relacion: $relacion}';
  }
}

// Enum para tipos de relación
enum TipoRelacion {
  familiar('Familiar'),
  amigo('Amigo'),
  pareja('Pareja'),
  emergencia('Contacto de Emergencia'),
  trabajo('Trabajo'),
  medico('Médico'),
  otro('Otro');

  const TipoRelacion(this.displayName);
  final String displayName;

  static TipoRelacion fromString(String value) {
    return TipoRelacion.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TipoRelacion.otro,
    );
  }
}

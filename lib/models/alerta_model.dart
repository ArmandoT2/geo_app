class Alerta {
  final String id;
  final String direccion;
  final String usuarioCreador;
  final DateTime fechaHora;
  final String detalle;
  final String status;
  final String? atendidoPor;
  final List<dynamic>? evidencia;
  final String? rutaAtencion;

  Alerta({
    required this.id,
    required this.direccion,
    required this.usuarioCreador,
    required this.fechaHora,
    required this.detalle,
    required this.status,
    this.atendidoPor,
    this.evidencia,
    this.rutaAtencion,
  });

  factory Alerta.fromJson(Map<String, dynamic> json) {
    return Alerta(
      id: json['_id'] ?? '',
      direccion: json['direccion'] ?? '',
      usuarioCreador: json['usuarioCreador'] ?? '',
      fechaHora: DateTime.parse(json['fechaHora']),
      detalle: json['detalle'] ?? '',
      status: json['status'] ?? '',
      atendidoPor: json['atendidoPor'],
      evidencia: json['evidencia'] != null ? List<dynamic>.from(json['evidencia']) : null,
      rutaAtencion: json['rutaAtencion'],
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
      'rutaAtencion': rutaAtencion,
    };
  }
}

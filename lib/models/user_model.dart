class User {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String genero;
  final String rol;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.genero,
    required this.rol,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['_id'],
    username: json['username'],
    fullName: json['fullName'],
    email: json['email'],
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
    genero: json['genero'] ?? '',
    rol: json['rol'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'username': username,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'address': address,
    'genero': genero,
    'rol': rol,
  };

  // Método para crear una copia con datos actualizados
  User copyWith({
    String? id,
    String? username,
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? genero,
    String? rol,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      genero: genero ?? this.genero,
      rol: rol ?? this.rol,
    );
  }
}

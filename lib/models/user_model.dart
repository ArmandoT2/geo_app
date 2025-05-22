class User {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String rol;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.rol,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['_id'],
    username: json['username'],
    fullName: json['fullName'],
    email: json['email'],
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
    rol: json['rol'] ?? '',
  );
}

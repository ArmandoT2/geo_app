import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/contacto_model.dart';

class ContactoService {
  final String _baseUrl = 'http://localhost:3000/api/contactos'; // Cambia esto

  Future<List<Contacto>> obtenerContactos(String usuarioId) async {
    final response = await http.get(Uri.parse('$_baseUrl/usuario/$usuarioId'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['contactos'];
      return data.map((e) => Contacto.fromJson(e)).toList();
    } else {
      throw Exception('Error al obtener contactos');
    }
  }

  Future<Contacto?> crearContacto(Contacto contacto) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/crear'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(contacto.toJson()),
    );

    if (response.statusCode == 200) {
      return Contacto.fromJson(json.decode(response.body)['contacto']);
    } else {
      throw Exception('Error al crear contacto');
    }
  }

  Future<Contacto?> actualizarContacto(Contacto contacto) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/${contacto.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(contacto.toJson()),
    );

    if (response.statusCode == 200) {
      return Contacto.fromJson(json.decode(response.body)['contacto']);
    } else {
      throw Exception('Error al actualizar contacto');
    }
  }

  Future<bool> eliminarContacto(String id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/$id'));

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Error al eliminar contacto');
    }
  }

  Future<bool> toggleNotificaciones(String id, bool estado) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/$id/notificaciones'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'estado': estado}),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Error al cambiar notificaciones');
    }
  }
}

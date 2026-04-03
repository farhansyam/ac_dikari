import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PhoneModel {
  final int id;
  final String label;
  final String phoneNumber;
  final bool isPrimary;

  PhoneModel({
    required this.id,
    required this.label,
    required this.phoneNumber,
    required this.isPrimary,
  });

  factory PhoneModel.fromJson(Map<String, dynamic> json) {
    return PhoneModel(
      id: json['id'],
      label: json['label'],
      phoneNumber: json['phone_number'],
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
    );
  }
}

class PhoneService {
  final String baseUrl;
  final AuthService authService;

  PhoneService({required this.baseUrl, required this.authService});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer ${authService.token}',
  };

  Future<List<PhoneModel>> getPhones() async {
    final response = await http.get(
      Uri.parse('$baseUrl/phones'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['phones'] as List)
          .map((e) => PhoneModel.fromJson(e))
          .toList();
    }
    throw Exception(data['message'] ?? 'Gagal memuat nomor.');
  }

  Future<PhoneModel> createPhone(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/phones'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return PhoneModel.fromJson(data['phone']);
    }
    throw Exception(data['message'] ?? 'Gagal menyimpan nomor.');
  }

  Future<PhoneModel> updatePhone(int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse('$baseUrl/phones/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return PhoneModel.fromJson(data['phone']);
    }
    throw Exception(data['message'] ?? 'Gagal memperbarui nomor.');
  }

  Future<void> deletePhone(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/phones/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Gagal menghapus nomor.');
    }
  }

  Future<void> setPrimary(int id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/phones/$id/primary'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Gagal mengubah nomor utama.');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// ─── Models ───────────────────────────────────────────────────────

class AddressModel {
  final int id;
  final String propertyType;
  final String label;
  final String provinceId;
  final String provinceName;
  final String cityId;
  final String cityName;
  final String districtId;
  final String districtName;
  final String? villageId;
  final String? villageName;
  final String fullAddress;
  final double? latitude;
  final double? longitude;
  final bool isPrimary;

  AddressModel({
    required this.id,
    required this.propertyType,
    required this.label,
    required this.provinceId,
    required this.provinceName,
    required this.cityId,
    required this.cityName,
    required this.districtId,
    required this.districtName,
    this.villageId,
    this.villageName,
    required this.fullAddress,
    this.latitude,
    this.longitude,
    required this.isPrimary,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'],
      propertyType: json['property_type'],
      label: json['label'],
      provinceId: json['province_id'],
      provinceName: json['province_name'],
      cityId: json['city_id'],
      cityName: json['city_name'],
      districtId: json['district_id'],
      districtName: json['district_name'],
      villageId: json['village_id'],
      villageName: json['village_name'],
      fullAddress: json['full_address'],
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'property_type': propertyType,
    'label': label,
    'province_id': provinceId,
    'province_name': provinceName,
    'city_id': cityId,
    'city_name': cityName,
    'district_id': districtId,
    'district_name': districtName,
    'village_id': villageId,
    'village_name': villageName,
    'full_address': fullAddress,
    'latitude': latitude,
    'longitude': longitude,
    'is_primary': isPrimary,
  };

  String get propertyIcon {
    switch (propertyType) {
      case 'kantor':
        return '🏢';
      case 'apartemen':
        return '🏙️';
      default:
        return '🏠';
    }
  }

  String get formattedAddress =>
      '$fullAddress, $districtName, $cityName, $provinceName';
}

class WilayahItem {
  final String id;
  final String name;

  WilayahItem({required this.id, required this.name});

  factory WilayahItem.fromJson(Map<String, dynamic> json) {
    return WilayahItem(
      id: json['id'].toString(),
      name: json['name'] ?? json['nama'] ?? '',
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────

class AddressService {
  final String baseUrl;
  final AuthService authService;

  AddressService({required this.baseUrl, required this.authService});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer ${authService.token}',
  };

  // ─── CRUD Alamat ─────────────────────────────────────────────

  Future<List<AddressModel>> getAddresses() async {
    final response = await http.get(
      Uri.parse('$baseUrl/addresses'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['addresses'] as List)
          .map((e) => AddressModel.fromJson(e))
          .toList();
    }
    throw Exception(data['message'] ?? 'Gagal memuat alamat.');
  }

  Future<AddressModel> createAddress(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/addresses'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return AddressModel.fromJson(data['address']);
    }
    throw Exception(data['message'] ?? 'Gagal menyimpan alamat.');
  }

  Future<AddressModel> updateAddress(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/addresses/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return AddressModel.fromJson(data['address']);
    }
    throw Exception(data['message'] ?? 'Gagal memperbarui alamat.');
  }

  Future<void> deleteAddress(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/addresses/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Gagal menghapus alamat.');
    }
  }

  Future<void> setPrimary(int id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/addresses/$id/primary'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Gagal mengubah alamat utama.');
    }
  }

  // ─── API Wilayah ─────────────────────────────────────────────

  Future<List<WilayahItem>> getProvinces() async {
    final response = await http.get(Uri.parse('$baseUrl/../api/provinces'));
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => WilayahItem.fromJson(e))
          .toList();
    }
    throw Exception('Gagal memuat provinsi.');
  }

  Future<List<WilayahItem>> getCities(String provinceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/../api/regencies/$provinceId'),
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => WilayahItem.fromJson(e))
          .toList();
    }
    throw Exception('Gagal memuat kota/kabupaten.');
  }

  Future<List<WilayahItem>> getDistricts(String cityId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/../api/districts/$cityId'),
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => WilayahItem.fromJson(e))
          .toList();
    }
    throw Exception('Gagal memuat kecamatan.');
  }

  Future<List<WilayahItem>> getVillages(String districtId) async {
    final response = await http.get(Uri.parse('$baseUrl/villages/$districtId'));
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => WilayahItem.fromJson(e))
          .toList();
    }
    throw Exception('Gagal memuat kelurahan/desa.');
  }
}

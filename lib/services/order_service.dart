import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// ─── Models ───────────────────────────────────────────────────────

class ServiceModel {
  final int id;
  final String name;
  final String description;
  final double basePrice;
  final double discount;
  final double finalPrice;
  final int bpId;
  final String bpName;
  final String? banner;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.discount,
    required this.finalPrice,
    required this.bpId,
    required this.bpName,
    this.banner,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      basePrice: (json['base_price'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      finalPrice: (json['final_price'] as num).toDouble(),
      bpId: json['bp_id'],
      bpName: json['bp_name'] ?? 'Dikari',
      banner: json['banner'],
    );
  }
}

class OrderItemInput {
  final int bpServiceId;
  final String name;
  final double finalPrice;
  int quantity;

  OrderItemInput({
    required this.bpServiceId,
    required this.name,
    required this.finalPrice,
    this.quantity = 1,
  });

  double get subtotal => finalPrice * quantity;
}

class OrderModel {
  final int id;
  final String status;
  final String scheduledDate;
  final String scheduledTime;
  final double apartmentSurcharge;
  final double discountAmount; // ← tambah
  final String? tripayReference;
  final double subtotal;
  final double totalAmount;
  final String? notes;
  final String bpName;
  final Map<String, dynamic> phone;
  final Map<String, dynamic> address;
  final List<Map<String, dynamic>> items;
  final String createdAt;
  final String paymentStatus; // ← tambah
  final String? tripayPaymentUrl; // ← tambah

  OrderModel({
    required this.id,
    required this.status,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.apartmentSurcharge,
    required this.discountAmount,
    this.tripayReference,
    required this.subtotal,
    required this.totalAmount,
    this.notes,
    required this.bpName,
    required this.phone,
    required this.address,
    required this.items,
    required this.createdAt,
    required this.paymentStatus,
    this.tripayPaymentUrl,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      status: json['status'],
      scheduledDate: json['scheduled_date'],
      scheduledTime: json['scheduled_time'],
      apartmentSurcharge: (json['apartment_surcharge'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num? ?? 0).toDouble(),
      tripayReference: json['tripay_reference'],
      subtotal: (json['subtotal'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      notes: json['notes'],
      bpName: json['bp_name'] ?? '-',
      phone: Map<String, dynamic>.from(json['phone'] ?? {}),
      address: Map<String, dynamic>.from(json['address'] ?? {}),
      items: List<Map<String, dynamic>>.from(json['items'] ?? []),
      createdAt: json['created_at'] ?? '',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      tripayPaymentUrl: json['tripay_payment_url'],
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'in_progress':
        return 'Sedang Dikerjakan';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'waiting_confirmation':
        return 'Menunggu Konfirmasimu';
      default:
        return status;
    }
  }
}

// ─── Service ──────────────────────────────────────────────────────

class OrderService {
  final String baseUrl;
  final AuthService authService;

  OrderService({required this.baseUrl, required this.authService});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer ${authService.token}',
  };

  Future<Map<String, dynamic>> getServices({String? city}) async {
    final uri = Uri.parse(
      '$baseUrl/services',
    ).replace(queryParameters: city != null ? {'city': city} : null);

    final response = await http.get(uri, headers: _headers);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        'services': (data['services'] as List)
            .map((e) => ServiceModel.fromJson(e))
            .toList(),
        'time_slots': List<String>.from(data['time_slots'] ?? []),
      };
    }
    throw Exception(data['message'] ?? 'Gagal memuat layanan.');
  }

  Future<OrderModel> createOrder(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return OrderModel.fromJson(data['order']);
    }
    throw Exception(data['message'] ?? 'Gagal membuat order.');
  }

  Future<List<OrderModel>> getOrders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['orders'] as List)
          .map((e) => OrderModel.fromJson(e))
          .toList();
    }
    throw Exception(data['message'] ?? 'Gagal memuat pesanan.');
  }

  Future<OrderModel> getOrder(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$id'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return OrderModel.fromJson(data['order']);
    }
    throw Exception(data['message'] ?? 'Gagal memuat detail pesanan.');
  }

  Future<void> cancelOrder(int id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/orders/$id/cancel'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Gagal membatalkan pesanan.');
    }
  }

  Future<void> confirmOrder(int id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/orders/$id/confirm'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Gagal konfirmasi pesanan.');
    }
  }
}

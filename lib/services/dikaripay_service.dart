import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DikariPayTransaction {
  final int id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String? description;
  final String createdAt;

  DikariPayTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    required this.createdAt,
  });

  factory DikariPayTransaction.fromJson(Map<String, dynamic> json) {
    return DikariPayTransaction(
      id: json['id'],
      type: json['type'],
      amount: (json['amount'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      description: json['description'],
      createdAt: json['created_at'] ?? '',
    );
  }

  String get typeLabel {
    switch (type) {
      case 'topup':
        return 'Topup';
      case 'payment':
        return 'Pembayaran';
      case 'refund':
        return 'Refund';
      default:
        return type;
    }
  }

  bool get isCredit => type == 'topup' || type == 'refund';
}

class DikariPayService {
  final String baseUrl;
  final AuthService authService;

  DikariPayService({required this.baseUrl, required this.authService});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer ${authService.token}',
  };

  Future<Map<String, dynamic>> getBalance() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dikaripay/balance'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {
        'balance': (data['balance'] as num).toDouble(),
        'transactions': (data['transactions'] as List)
            .map((e) => DikariPayTransaction.fromJson(e))
            .toList(),
      };
    }
    throw Exception(data['message'] ?? 'Gagal memuat saldo.');
  }

  Future<Map<String, dynamic>> topup({
    required int amount,
    required String paymentMethod,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dikaripay/topup'),
      headers: _headers,
      body: jsonEncode({'amount': amount, 'payment_method': paymentMethod}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Gagal membuat topup.');
  }

  Future<Map<String, dynamic>> payWithBalance({
    required int orderId,
    String? couponCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dikaripay/pay'),
      headers: _headers,
      body: jsonEncode({'order_id': orderId, 'coupon_code': couponCode}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Gagal membayar dengan DikariPay.');
  }
}

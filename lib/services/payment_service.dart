import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PaymentChannel {
  final String code;
  final String name;
  final String group;
  final double feeFlat;
  final double feePercent;
  final String? iconUrl;

  PaymentChannel({
    required this.code,
    required this.name,
    required this.group,
    required this.feeFlat,
    required this.feePercent,
    this.iconUrl,
  });

  factory PaymentChannel.fromJson(Map<String, dynamic> json) {
    return PaymentChannel(
      code: json['code'],
      name: json['name'],
      group: json['group'],
      feeFlat: (json['fee_flat'] as num).toDouble(),
      feePercent: (json['fee_percent'] as num).toDouble(),
      iconUrl: json['icon_url'],
    );
  }

  double calculateFee(double amount) {
    return feeFlat + (amount * feePercent / 100);
  }
}

class CouponResult {
  final bool valid;
  final String message;
  final double discountAmount;
  final String? couponCode;
  final String? couponName;
  final double? discountPercent;

  CouponResult({
    required this.valid,
    required this.message,
    required this.discountAmount,
    this.couponCode,
    this.couponName,
    this.discountPercent,
  });

  factory CouponResult.fromJson(Map<String, dynamic> json) {
    final coupon = json['coupon'];
    return CouponResult(
      valid: json['valid'] == true,
      message: json['message'] ?? '',
      discountAmount: (json['discount_amount'] as num? ?? 0).toDouble(),
      couponCode: coupon?['code'],
      couponName: coupon?['name'],
      discountPercent: (coupon?['discount_percent'] as num?)?.toDouble(),
    );
  }
}

class PaymentService {
  final String baseUrl;
  final AuthService authService;

  PaymentService({required this.baseUrl, required this.authService});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer ${authService.token}',
  };

  Future<List<PaymentChannel>> getChannels() async {
    final response = await http.get(
      Uri.parse('$baseUrl/payment/channels'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['channels'] as List)
          .map((e) => PaymentChannel.fromJson(e))
          .toList();
    }
    throw Exception(data['message'] ?? 'Gagal memuat metode pembayaran.');
  }

  Future<CouponResult> validateCoupon(String code, double orderTotal) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payment/validate-coupon'),
      headers: _headers,
      body: jsonEncode({'code': code, 'order_total': orderTotal}),
    );
    final data = jsonDecode(response.body);
    return CouponResult.fromJson(data);
  }

  Future<Map<String, dynamic>> createTransaction({
    required int orderId,
    required String paymentMethod,
    String? couponCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payment/create'),
      headers: _headers,
      body: jsonEncode({
        'order_id': orderId,
        'payment_method': paymentMethod,
        'coupon_code': couponCode,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Gagal membuat transaksi.');
  }
}

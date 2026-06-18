import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

// ─── Models ───────────────────────────────────────────────────────

class SubscriptionPackageModel {
  final int id;
  final String type;
  final String name;
  final int intervalMonths;
  final int totalSessions;
  final double priceMultiplier;
  final String? description;
  final bool isActive;

  SubscriptionPackageModel({
    required this.id,
    required this.type,
    required this.name,
    required this.intervalMonths,
    required this.totalSessions,
    required this.priceMultiplier,
    this.description,
    required this.isActive,
  });

  factory SubscriptionPackageModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPackageModel(
      id: json['id'],
      type: json['type'],
      name: json['name'],
      intervalMonths: (json['interval_months'] as num? ?? 0).toInt(),
      totalSessions: (json['total_sessions'] as num? ?? 0).toInt(),
      priceMultiplier:
          double.tryParse(json['price_multiplier'].toString()) ?? 1.0,
      description: json['description'],
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }

  int get discountPercent => ((1 - priceMultiplier) * 100).round();
}

class SubscriptionServiceItem {
  final int bpServiceId;
  final String name;
  final double basePrice;
  final String? bannerUrl;
  int quantity;

  SubscriptionServiceItem({
    required this.bpServiceId,
    required this.name,
    required this.basePrice,
    this.bannerUrl,
    this.quantity = 1,
  });

  factory SubscriptionServiceItem.fromJson(Map<String, dynamic> json) {
    return SubscriptionServiceItem(
      bpServiceId: json['bp_service_id'],
      name: json['name'],
      basePrice: double.tryParse(json['base_price'].toString()) ?? 0.0,
      bannerUrl: json['banner_url'],
    );
  }

  double get subtotalPerSession => basePrice * quantity;
}

class SubscriptionPreview {
  final SubscriptionPackageModel package;
  final double subtotalPerSession;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final int totalSessions;

  SubscriptionPreview({
    required this.package,
    required this.subtotalPerSession,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.totalSessions,
  });

  factory SubscriptionPreview.fromJson(
    Map<String, dynamic> json,
    SubscriptionPackageModel package,
  ) {
    return SubscriptionPreview(
      package: package,
      subtotalPerSession: (json['subtotal_per_session'] as num).toDouble(),
      subtotal: double.tryParse(json['subtotal'].toString()) ?? 0.0,
      discountAmount:
          double.tryParse(json['discount_amount'].toString()) ?? 0.0,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      totalSessions: json['total_sessions'],
    );
  }
}

class SubscriptionSessionModel {
  final int id;
  final int sessionNumber;
  final String scheduledDate;
  final String scheduledTime;
  final String status;
  final Map<String, dynamic>? technician;
  final Map<String, dynamic>? report;

  SubscriptionSessionModel({
    required this.id,
    required this.sessionNumber,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    this.technician,
    this.report,
  });

  factory SubscriptionSessionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionSessionModel(
      id: json['id'],
      sessionNumber: json['session_number'],
      scheduledDate: json['scheduled_date'] ?? '',
      scheduledTime: json['scheduled_time'] ?? '',
      status: json['status'],
      technician: json['technician'] != null
          ? Map<String, dynamic>.from(json['technician'])
          : null,
      report: json['report'] != null
          ? Map<String, dynamic>.from(json['report'])
          : null,
    );
  }

  bool get canConfirm => status == 'waiting_confirmation';
  bool get isCompleted => status == 'completed';

  String get statusLabel {
    switch (status) {
      case 'scheduled':
        return 'Terjadwal';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'in_progress':
        return 'Sedang Dikerjakan';
      case 'waiting_confirmation':
        return 'Menunggu Konfirmasi';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }
}

class SubscriptionModel {
  final int id;
  final String packageType;
  final String packageName;
  final int intervalMonths;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final String paymentStatus;
  final String? tripayPaymentUrl;
  final String status;
  final String? startsAt;
  final String? expiresAt;
  final int totalSessions;
  final int completedSessions;
  final List<SubscriptionSessionModel> sessions;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? address;
  final Map<String, dynamic>? userPhone;

  SubscriptionModel({
    required this.id,
    required this.packageType,
    required this.packageName,
    required this.intervalMonths,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentStatus,
    this.tripayPaymentUrl,
    required this.status,
    this.startsAt,
    this.expiresAt,
    required this.totalSessions,
    required this.completedSessions,
    required this.sessions,
    required this.items,
    this.address,
    this.userPhone,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    final pkg = json['package'] ?? {};
    return SubscriptionModel(
      id: json['id'],
      packageType: (pkg['type'] ?? json['package_type'] ?? '').toString(),
      packageName: (pkg['name'] ?? json['package_name'] ?? '').toString(),
      intervalMonths: (pkg['interval_months'] as num? ?? 0).toInt(),
      subtotal: double.tryParse(json['subtotal'].toString()) ?? 0.0,
      discountAmount:
          double.tryParse(json['discount_amount'].toString()) ?? 0.0,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      paymentStatus: (json['payment_status'] ?? 'unpaid').toString(),
      tripayPaymentUrl: json['tripay_payment_url'],
      status: (json['status'] ?? 'pending').toString(),
      startsAt: json['starts_at'],
      expiresAt: json['expires_at'],
      totalSessions:
          (pkg['total_sessions'] as num? ?? json['total_sessions'] as num? ?? 0)
              .toInt(),
      completedSessions: (json['completed_sessions'] as num? ?? 0).toInt(),
      sessions: json['sessions'] != null
          ? (json['sessions'] as List)
                .map((s) => SubscriptionSessionModel.fromJson(s))
                .toList()
          : [],
      items: json['items'] != null
          ? List<Map<String, dynamic>>.from(json['items'])
          : [],
      address: json['address'] != null
          ? Map<String, dynamic>.from(json['address'])
          : null,
      userPhone: json['user_phone'] != null
          ? Map<String, dynamic>.from(json['user_phone'])
          : null,
    );
  }

  bool get isPaid => paymentStatus == 'paid';
  bool get needsSchedule => isPaid && sessions.isEmpty;

  SubscriptionSessionModel? get nextSession {
    final pending = sessions
        .where((s) => !s.isCompleted && s.status != 'cancelled')
        .toList();
    return pending.isNotEmpty ? pending.first : null;
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'active':
        return 'Aktif';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }
}

// ─── Service ──────────────────────────────────────────────────────

class SubscriptionService {
  final String baseUrl;
  final AuthService authService;

  SubscriptionService({required this.baseUrl, required this.authService});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer ${authService.token}',
  };

  Future<List<SubscriptionPackageModel>> getPackages() async {
    final res = await http.get(
      Uri.parse('$baseUrl/subscriptions/packages'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return (data['packages'] as List)
          .map((e) => SubscriptionPackageModel.fromJson(e))
          .toList();
    }
    throw Exception(data['message'] ?? 'Gagal memuat paket.');
  }

  Future<Map<String, dynamic>> getServices(int addressId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/subscriptions/services?address_id=$addressId'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return {
        'bp_id': data['bp_id'],
        'bp_name': data['bp_name'],
        'services': (data['services'] as List)
            .map((e) => SubscriptionServiceItem.fromJson(e))
            .toList(),
      };
    }
    throw Exception(
      data['message'] ??
          'Gagal memuat layanan. Layanan mungkin belum tersedia di area kamu.',
    );
  }

  Future<SubscriptionPreview> preview({
    required int packageId,
    required int addressId,
    required List<Map<String, dynamic>> items,
    required SubscriptionPackageModel package,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subscriptions/preview'),
      headers: _headers,
      body: jsonEncode({
        'package_id': packageId,
        'address_id': addressId,
        'items': items,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200)
      return SubscriptionPreview.fromJson(data, package);
    throw Exception(data['message'] ?? 'Gagal menghitung harga.');
  }

  Future<SubscriptionModel> store({
    required int packageId,
    required int addressId,
    required int userPhoneId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subscriptions'),
      headers: _headers,
      body: jsonEncode({
        'package_id': packageId,
        'address_id': addressId,
        'user_phone_id': userPhoneId,
        'items': items,
        'payment_method': paymentMethod,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      return SubscriptionModel.fromJson(data['subscription']);
    }
    throw Exception(data['message'] ?? 'Gagal membuat langganan.');
  }

  Future<List<SubscriptionModel>> index() async {
    final res = await http.get(
      Uri.parse('$baseUrl/subscriptions'),
      headers: _headers,
    );
    debugPrint('=== SUBSCRIPTION INDEX: ${res.statusCode} ${res.body}');
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return (data['subscriptions'] as List)
          .map((e) => SubscriptionModel.fromJson(e))
          .toList();
    }
    throw Exception(data['message'] ?? 'Gagal memuat langganan.');
  }

  Future<SubscriptionModel> show(int id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/subscriptions/$id'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return SubscriptionModel.fromJson(data['subscription']);
    }
    throw Exception(data['message'] ?? 'Gagal memuat detail langganan.');
  }

  Future<void> setSchedule({
    required int subscriptionId,
    required List<Map<String, dynamic>> schedules,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subscriptions/$subscriptionId/schedule'),
      headers: _headers,
      body: jsonEncode({'schedules': schedules}),
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Gagal menyimpan jadwal.');
    }
  }

  Future<void> confirmSession({
    required int subscriptionId,
    required int sessionId,
  }) async {
    final res = await http.post(
      Uri.parse(
        '$baseUrl/subscriptions/$subscriptionId/sessions/$sessionId/confirm',
      ),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Gagal konfirmasi sesi.');
    }
  }
}

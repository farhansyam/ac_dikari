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
  final String category;

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
    required this.category,
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
      category: json['category'] ?? 'cuci_reguler',
    );
  }

  bool get isPasangBaru => category == 'pasang_baru';
  bool get isUnit => category == 'unit';
  bool get isRelokasi => category == 'relokasi';
  bool get isPerbaikanSurvey => category == 'service_perbaikan_survey';
  bool get isPerbaikanService => category == 'service_perbaikan_service';
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

class SurveyReportModel {
  final int id;
  final int orderId;
  final String kondisiUnit;
  final List<String> bagianBermasalah;
  final String? catatan;
  final String rekomendasi;
  final String? photoBefore;
  final String? photoAfter;
  final String? customerResponse;
  final String? respondedAt;

  SurveyReportModel({
    required this.id,
    required this.orderId,
    required this.kondisiUnit,
    required this.bagianBermasalah,
    this.catatan,
    required this.rekomendasi,
    this.photoBefore,
    this.photoAfter,
    this.customerResponse,
    this.respondedAt,
  });

  factory SurveyReportModel.fromJson(Map<String, dynamic> json) {
    return SurveyReportModel(
      id: json['id'],
      orderId: json['order_id'],
      kondisiUnit: json['kondisi_unit'],
      bagianBermasalah: List<String>.from(json['bagian_bermasalah'] ?? []),
      catatan: json['catatan'],
      rekomendasi: json['rekomendasi'],
      photoBefore: json['photo_before'],
      photoAfter: json['photo_after'],
      customerResponse: json['customer_response'],
      respondedAt: json['responded_at'],
    );
  }

  bool get isRekomendasiCuci => rekomendasi == 'cuci_unit';
  bool get isRekomendasiPerbaikan => rekomendasi == 'perbaikan';
  String get rekomendasiLabel =>
      isRekomendasiCuci ? '🫧 Cuci Unit' : '🔩 Perbaikan';

  String get kondisiLabel {
    switch (kondisiUnit) {
      case 'normal':
        return 'Normal';
      case 'kotor':
        return 'Kotor';
      case 'rusak':
        return 'Rusak';
      default:
        return kondisiUnit;
    }
  }
}

class OrderModel {
  final int id;
  final String status;
  final String scheduledDate;
  final String scheduledTime;
  final double apartmentSurcharge;
  final double discountAmount;
  final double transportFee;
  final String? tripayReference;
  final double subtotal;
  final double totalAmount;
  final String? notes;
  final String bpName;
  final Map<String, dynamic> phone;
  final Map<String, dynamic> address;
  final Map<String, dynamic>? originAddress;
  final List<Map<String, dynamic>> items;
  final String createdAt;
  final String paymentStatus;
  final String? tripayPaymentUrl;
  final Map<String, dynamic>? report;
  final String? technicianName;
  final String? secondTechnicianName;
  final Map<String, dynamic>? rating;
  final Map<String, dynamic>? complaint;
  final String? orderType;
  final String? relocationType;
  final bool splitTechnician;
  // ─── Perbaikan fields ─────────────────────────────────────
  final bool isPerbaikan;
  final String? perbaikanPhase;
  final int? phase2OrderId;
  final int? surveyOrderId;
  final List<String> keluhan;
  final String? keluhanLainnya;

  OrderModel({
    required this.id,
    required this.status,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.apartmentSurcharge,
    required this.discountAmount,
    required this.transportFee,
    this.tripayReference,
    required this.subtotal,
    required this.totalAmount,
    this.notes,
    required this.bpName,
    required this.phone,
    required this.address,
    this.originAddress,
    required this.items,
    required this.createdAt,
    required this.paymentStatus,
    this.tripayPaymentUrl,
    this.report,
    this.technicianName,
    this.secondTechnicianName,
    this.rating,
    this.complaint,
    this.orderType,
    this.relocationType,
    this.splitTechnician = false,
    this.isPerbaikan = false,
    this.perbaikanPhase,
    this.phase2OrderId,
    this.surveyOrderId,
    this.keluhan = const [],
    this.keluhanLainnya,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      status: json['status'],
      scheduledDate: json['scheduled_date'] ?? '',
      scheduledTime: json['scheduled_time'] ?? '',
      apartmentSurcharge: (json['apartment_surcharge'] as num? ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] as num? ?? 0).toDouble(),
      transportFee: (json['transport_fee'] as num? ?? 0).toDouble(),
      tripayReference: json['tripay_reference'],
      subtotal: (json['subtotal'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      notes: json['notes'],
      bpName: json['bp_name'] ?? '-',
      phone: Map<String, dynamic>.from(json['phone'] ?? {}),
      address: Map<String, dynamic>.from(json['address'] ?? {}),
      originAddress: json['origin_address'] != null
          ? Map<String, dynamic>.from(json['origin_address'])
          : null,
      items: List<Map<String, dynamic>>.from(json['items'] ?? []),
      createdAt: json['created_at'] ?? '',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      tripayPaymentUrl: json['tripay_payment_url'],
      report: json['report'] != null
          ? Map<String, dynamic>.from(json['report'])
          : null,
      technicianName: json['technician_name'],
      secondTechnicianName: json['second_technician_name'],
      rating: json['rating'] != null
          ? Map<String, dynamic>.from(json['rating'])
          : null,
      complaint: json['complaint'] != null
          ? Map<String, dynamic>.from(json['complaint'])
          : null,
      orderType: json['order_type'],
      relocationType: json['relocation_type'],
      splitTechnician: json['split_technician'] ?? false,
      isPerbaikan: json['is_perbaikan'] ?? false,
      perbaikanPhase: json['perbaikan_phase'],
      phase2OrderId: json['phase2_order_id'],
      surveyOrderId: json['survey_order_id'],
      keluhan: List<String>.from(json['keluhan'] ?? []),
      keluhanLainnya: json['keluhan_lainnya'],
    );
  }

  bool get isRelokasi => orderType == 'relokasi';
  bool get isDiffLocation => relocationType == 'different_location';
  bool get needsTransportConfirmation => status == 'pending_transport_fee_set';
  bool get isSurveyPhase => isPerbaikan && perbaikanPhase == 'survey';
  bool get isPhase2 => isPerbaikan && perbaikanPhase == 'phase2';
  bool get isWaitingCustomerResponse => status == 'waiting_customer_response';
  bool get isPasangBaru => items.any(
    (item) => // ← tambah
        item['category'] == 'pasang_baru' || item['category'] == 'unit',
  );
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'pending_transport_fee':
        return 'Menunggu Biaya Transportasi';
      case 'pending_transport_fee_set':
        return 'Konfirmasi Biaya Transportasi';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'in_progress':
        return 'Sedang Dikerjakan';
      case 'survey_in_progress':
        return 'Survei Sedang Berlangsung';
      case 'waiting_customer_response':
        return 'Menunggu Keputusanmu';
      case 'waiting_confirmation':
        return 'Menunggu Konfirmasimu';
      case 'warranty':
        return 'Masa Garansi';
      case 'complained':
        return 'Dikomplain';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'disassembled':
        return 'Sudah Dibongkar, Menunggu Pemasangan';
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

  // ─── GET layanan ───────────────────────────────────────────
  Future<Map<String, dynamic>> getServices({
    String? city,
    String? category,
  }) async {
    final params = <String, String>{};
    if (city != null) params['city'] = city;
    if (category != null) params['category'] = category;

    final uri = Uri.parse(
      '$baseUrl/services',
    ).replace(queryParameters: params.isEmpty ? null : params);
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

  // ─── POST create order biasa ───────────────────────────────
  Future<OrderModel> createOrder(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return OrderModel.fromJson(data['order']);
    throw Exception(data['message'] ?? 'Gagal membuat order.');
  }

  // ─── POST create order perbaikan ──────────────────────────
  Future<OrderModel> createPerbaikanOrder(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/perbaikan'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return OrderModel.fromJson(data['order']);
    throw Exception(data['message'] ?? 'Gagal membuat order perbaikan.');
  }

  // ─── GET list orders ───────────────────────────────────────
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

  // ─── GET detail order ─────────────────────────────────────
  Future<OrderModel> getOrder(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$id'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return OrderModel.fromJson(data['order']);
    throw Exception(data['message'] ?? 'Gagal memuat detail pesanan.');
  }

  // ─── PATCH cancel order ────────────────────────────────────
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

  // ─── PATCH confirm order (customer selesai) ────────────────
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

  // ─── PATCH konfirmasi biaya transport ─────────────────────
  Future<void> confirmTransportFee(int id, bool confirm) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/orders/$id/confirm-transport'),
      headers: _headers,
      body: jsonEncode({'confirm': confirm}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(
        data['message'] ?? 'Gagal mengkonfirmasi biaya transportasi.',
      );
    }
  }

  // ─── GET hasil survey report ───────────────────────────────
  Future<Map<String, dynamic>> getSurveyReport(int orderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId/survey-report'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {
        'order': OrderModel.fromJson(data['order']),
        'report': SurveyReportModel.fromJson(data['report']),
      };
    }
    throw Exception(data['message'] ?? 'Gagal memuat hasil survey.');
  }

  // ─── POST customer respond survey (lanjut / tidak) ─────────
  Future<OrderModel?> respondSurvey({
    required int orderId,
    required String response, // 'lanjut' atau 'tidak'
    int? bpServiceId, // wajib jika response = 'lanjut'
  }) async {
    final payload = <String, dynamic>{'response': response};
    if (bpServiceId != null) payload['bp_service_id'] = bpServiceId;

    final res = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/survey-respond'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      if (data['phase2_order'] != null) {
        return OrderModel.fromJson(data['phase2_order']);
      }
      return null;
    }
    throw Exception(data['message'] ?? 'Gagal mengirim konfirmasi.');
  }
}

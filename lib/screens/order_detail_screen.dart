import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import 'payment_webview_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late OrderService _orderService;
  OrderModel? _order;
  SurveyReportModel? _surveyReport;
  bool _loading = true;
  bool _cancelling = false;
  bool _confirming = false;
  bool _respondingSurvey = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _orderService = OrderService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      setState(() => _loading = true);
      final order = await _orderService.getOrder(widget.orderId);

      // Load survey report jika status waiting_customer_response
      SurveyReportModel? report;
      if (order.isWaitingCustomerResponse) {
        try {
          final result = await _orderService.getSurveyReport(order.id);
          report = result['report'] as SurveyReportModel;
        } catch (e) {
          debugPrint('=== getSurveyReport ERROR: $e'); // ← tambah
        }
      }

      if (!mounted) return;
      setState(() {
        _order = order;
        _surveyReport = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar(e.toString());
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Pesanan?'),
        content: const Text(
          'Pesanan yang sudah dibatalkan tidak dapat dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _cancelling = true);
    try {
      await _orderService.cancelOrder(widget.orderId);
      await _loadOrder();
      if (!mounted) return;
      _showSnackBar('Pesanan berhasil dibatalkan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      _showSnackBar(e.toString());
    }
  }

  Future<void> _confirmOrder() async {
    try {
      await _orderService.confirmOrder(widget.orderId);
      await _loadOrder();
      if (!mounted) return;
      _showSnackBar('Pesanan dikonfirmasi! Masa garansi 7 hari aktif.');
      if (_order?.rating == null) {
        Navigator.of(context)
            .pushNamed(
              '/rating',
              arguments: {
                'orderId': widget.orderId,
                'technicianName': _order?.technicianName ?? 'Teknisi',
                'secondTechnicianName': _order?.secondTechnicianName,
                'splitTechnician': _order?.splitTechnician ?? false,
              },
            )
            .then((_) => _loadOrder());
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    }
  }

  Future<void> _handleTransportFee(bool accept) async {
    final label = accept ? 'Setuju' : 'Tolak';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$label Biaya Transportasi?'),
        content: Text(
          accept
              ? 'Anda menyetujui biaya transportasi ${_formatCurrency(_order!.transportFee)}. Lanjutkan ke pembayaran?'
              : 'Anda menolak biaya transportasi. Pesanan akan dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: accept ? AppTheme.primary : Colors.red,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _confirming = true);
    try {
      await _orderService.confirmTransportFee(widget.orderId, accept);
      await _loadOrder();
      if (!mounted) return;
      setState(() => _confirming = false);
      if (accept) {
        Navigator.pushNamed(context, '/payment', arguments: _order);
      } else {
        _showSnackBar('Pesanan dibatalkan.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      _showSnackBar(e.toString());
    }
  }

  // ─── Respond Survey ───────────────────────────────────────────
  Future<void> _respondSurvey(String response) async {
    if (response == 'lanjut' && _surveyReport == null) return;

    // Jika lanjut, perlu pilih service fase 2 dulu
    if (response == 'lanjut') {
      await _showPilihServiceFase2();
      return;
    }

    // Tidak lanjut — langsung konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tidak Lanjutkan?'),
        content: const Text(
          'Biaya survey akan ditagihkan. Pesanan akan selesai di sini tanpa perbaikan lebih lanjut.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ya, Tidak Lanjut'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _respondingSurvey = true);
    try {
      await _orderService.respondSurvey(
        orderId: widget.orderId,
        response: 'tidak',
      );
      await _loadOrder();
      if (!mounted) return;
      _showSnackBar('Pesanan survei selesai. Terima kasih.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _respondingSurvey = false);
    }
  }

  Future<void> _showPilihServiceFase2() async {
    final report = _surveyReport!;
    final category = report.isRekomendasiCuci
        ? 'cuci_reguler'
        : 'service_perbaikan_service';

    // Load services fase 2
    List<ServiceModel> services = [];
    try {
      final result = await _orderService.getServices(category: category);
      services = result['services'] as List<ServiceModel>;
    } catch (e) {
      _showSnackBar('Gagal memuat layanan: $e');
      return;
    }

    if (!mounted) return;

    ServiceModel? selected;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                report.isRekomendasiCuci
                    ? '🫧 Pilih Layanan Cuci'
                    : '🔩 Pilih Layanan Perbaikan',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sesuai rekomendasi teknisi: ${report.rekomendasiLabel}',
                style: TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              if (services.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Layanan tidak tersedia.'),
                  ),
                )
              else
                ...services.map((s) {
                  final isSelected = selected?.id == s.id;
                  return GestureDetector(
                    onTap: () => setModalState(() => selected = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(s.finalPrice),
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selected == null ? null : () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Lanjutkan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // GANTI bagian ini (dari "if (selected == null) return;" sampai akhir method):

    if (selected == null) return;

    setState(() => _respondingSurvey = true);
    try {
      final phase2Order = await _orderService.respondSurvey(
        orderId: widget.orderId,
        response: 'lanjut',
        bpServiceId: selected!.id,
      );
      if (!mounted) return;
      if (phase2Order != null) {
        // Navigate ke payment fase 2
        Navigator.pushReplacementNamed(
          context,
          '/payment',
          arguments: phase2Order,
        );
      } else {
        await _loadOrder();
        _showSnackBar('Order fase 2 berhasil dibuat.');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _respondingSurvey = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatCurrency(double amount) =>
      'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  bool _isChecked(dynamic value) => value == true || value == 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(_order != null ? 'Order #${_order!.id}' : 'Detail Pesanan'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
          ? const Center(child: Text('Pesanan tidak ditemukan.'))
          : _buildContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildContent() {
    final order = _order!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(order),
        const SizedBox(height: 16),

        // ─── Banner perbaikan ─────────────────────────────────
        if (order.isPerbaikan) ...[
          _buildPerbaikanBanner(order),
          const SizedBox(height: 16),
        ],

        // ─── Survey result card ───────────────────────────────
        if (order.isWaitingCustomerResponse && _surveyReport != null) ...[
          _buildSurveyResultCard(_surveyReport!),
          const SizedBox(height: 16),
        ],

        // ─── Banner konfirmasi biaya transport ────────────────
        if (order.status == 'pending_transport_fee_set') ...[
          _buildTransportFeeConfirmCard(order),
          const SizedBox(height: 16),
        ],

        // ─── Banner menunggu transport fee dari BP ────────────
        if (order.status == 'pending_transport_fee') ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Menunggu mitra menentukan biaya transportasi.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ─── Layanan ──────────────────────────────────────────
        _buildSection(
          title: 'Layanan Dipesan',
          child: Column(
            children: [
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.ac_unit_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${item['quantity']} unit · ${_formatCurrency((item['unit_price'] as num).toDouble())} / unit',
                              style: TextStyle(
                                color: AppTheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatCurrency((item['subtotal'] as num).toDouble()),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(color: Colors.grey.shade100),
              if (order.apartmentSurcharge > 0)
                _buildPriceRow('Biaya Apartemen', order.apartmentSurcharge),
              if (order.discountAmount > 0)
                _buildPriceRow(
                  'Diskon Kupon',
                  -order.discountAmount,
                  color: Colors.green.shade600,
                ),
              if (order.transportFee > 0)
                _buildPriceRow(
                  'Biaya Transportasi',
                  order.transportFee,
                  color: Colors.orange.shade700,
                ),
              const SizedBox(height: 4),
              _buildPriceRow(
                'Total',
                order.totalAmount,
                isBold: true,
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Jadwal ───────────────────────────────────────────
        _buildSection(
          title: 'Jadwal',
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                '${order.scheduledDate} · ${order.scheduledTime}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Kontak ───────────────────────────────────────────
        _buildSection(
          title: 'Kontak',
          child: Row(
            children: [
              const Icon(
                Icons.phone_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.phone['label'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    order.phone['phone_number'] ?? '',
                    style: TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Alamat ───────────────────────────────────────────
        _buildSection(
          title: 'Alamat',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.address['label'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      order.address['full_address'] ?? '',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Mitra & Teknisi ──────────────────────────────────
        _buildSection(
          title: 'Mitra',
          child: Row(
            children: [
              const Icon(
                Icons.business_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.bpName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (order.technicianName != null)
                      Text(
                        'Teknisi: ${order.technicianName}',
                        style: TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── Laporan Pengerjaan ───────────────────────────────
        if (order.report != null) ...[
          const SizedBox(height: 16),
          _buildSection(
            title: 'Laporan Pengerjaan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              order.report!['photo_before'] ?? '',
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sebelum',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              order.report!['photo_after'] ?? '',
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sesudah',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Checklist Pengerjaan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                // GANTI

                // JADI — cek category item
                if (order.isPhase2 &&
                    order.items.any(
                      (i) => i['category'] == 'service_perbaikan_service',
                    )) ...[
                  // Checklist perbaikan
                  _buildChecklistItem(
                    'Komponen bermasalah sudah diperbaiki/diganti',
                    _isChecked(order.report!['remote_working']),
                  ),
                  _buildChecklistItem(
                    'AC menyala normal',
                    _isChecked(order.report!['unit_installed']),
                  ),
                  _buildChecklistItem(
                    'AC sudah dingin',
                    _isChecked(order.report!['cooling_test']),
                  ),
                  _buildChecklistItem(
                    'Kebocoran/rembesan dicek',
                    _isChecked(order.report!['piping_neat']),
                  ),
                  _buildChecklistItem(
                    'Kelistrikan dan kabel rapi',
                    _isChecked(order.report!['electrical_checked']),
                  ),
                ] else if (order.isPasangBaru) ...[
                  _buildChecklistItem(
                    'Unit terpasang dengan benar',
                    _isChecked(order.report!['unit_installed']),
                  ),
                  _buildChecklistItem(
                    'Instalasi pipa rapi',
                    _isChecked(order.report!['piping_neat']),
                  ),
                  _buildChecklistItem(
                    'Test pendinginan',
                    _isChecked(order.report!['cooling_test']),
                  ),
                  _buildChecklistItem(
                    'Kelistrikan dicek',
                    _isChecked(order.report!['electrical_checked']),
                  ),
                  _buildChecklistItem(
                    'Remote berfungsi',
                    _isChecked(order.report!['remote_working']),
                  ),
                ] else ...[
                  // Cuci AC biasa (termasuk fase 2 rekomendasi cuci)
                  _buildChecklistItem(
                    'Filter dibersihkan',
                    _isChecked(order.report!['filter_cleaned']),
                  ),
                  _buildChecklistItem(
                    'Freon dicek',
                    _isChecked(order.report!['freon_checked']),
                  ),
                  _buildChecklistItem(
                    'Saluran pembuangan dibersihkan',
                    _isChecked(order.report!['drain_cleaned']),
                  ),
                  _buildChecklistItem(
                    'Kelistrikan dicek',
                    _isChecked(order.report!['electrical_checked']),
                  ),
                ],
                if ((order.report!['notes'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Catatan Teknisi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    order.report!['notes'],
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],

        // ─── Garansi ──────────────────────────────────────────
        if (order.status == 'warranty') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  color: Colors.teal.shade700,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Masa garansi aktif. Ajukan komplain jika ada masalah.',
                    style: TextStyle(color: Colors.teal.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context)
                  .pushNamed('/complaint', arguments: order.id)
                  .then((result) {
                    if (result == true) _loadOrder();
                  }),
              icon: const Icon(Icons.warning_rounded, color: Colors.red),
              label: const Text('Ajukan Komplain'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],

        // ─── Status komplain ──────────────────────────────────
        if (order.status == 'complained') ...[
          const SizedBox(height: 16),
          _buildSection(
            title: 'Status Komplain',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      order.complaint?['status_label'] ?? 'Sedang Diproses',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if ((order.complaint?['bp_comment'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      order.complaint!['bp_comment'],
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // ─── Rating ───────────────────────────────────────────
        if (order.status == 'completed' && order.rating != null) ...[
          const SizedBox(height: 16),
          _buildSection(
            title: 'Ulasan Kamu',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < (order.rating!['rating'] as int)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                ),
                if ((order.rating!['review'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    order.rating!['review'],
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],

        if (order.status == 'completed' && order.rating == null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context)
                  .pushNamed(
                    '/rating',
                    arguments: {
                      'orderId': order.id,
                      'technicianName': order.technicianName ?? 'Teknisi',
                      'secondTechnicianName': order.secondTechnicianName,
                      'splitTechnician': order.splitTechnician,
                    },
                  )
                  .then((_) => _loadOrder()),
              icon: const Icon(Icons.star_rounded, color: Colors.amber),
              label: const Text('Beri Ulasan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildKeluhanSection(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Keluhan Customer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (order.keluhan.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: order.keluhan
                  .map(
                    (k) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        k,
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if ((order.keluhanLainnya ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Lainnya: ${order.keluhanLainnya}',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Perbaikan Banner ─────────────────────────────────────────
  Widget _buildPerbaikanBanner(OrderModel order) {
    final isPhase2 = order.isPhase2;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.build_rounded, color: Colors.purple.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPhase2
                      ? 'Service Perbaikan — Fase 2'
                      : 'Service Perbaikan — Survey',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  isPhase2
                      ? 'Teknisi sedang mengerjakan perbaikan AC Anda.'
                      : 'Teknisi akan datang untuk survey kondisi AC Anda terlebih dahulu.',
                  style: TextStyle(color: Colors.purple.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Survey Result Card ───────────────────────────────────────
  Widget _buildSurveyResultCard(SurveyReportModel report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.assignment_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Hasil Survey Teknisi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Menunggu Keputusanmu',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto before/after survey
                if (report.photoBefore != null ||
                    report.photoAfter != null) ...[
                  Row(
                    children: [
                      if (report.photoBefore != null)
                        Expanded(
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  report.photoBefore!,
                                  height: 100,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 100,
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sebelum',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (report.photoBefore != null &&
                          report.photoAfter != null)
                        const SizedBox(width: 10),
                      if (report.photoAfter != null)
                        Expanded(
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  report.photoAfter!,
                                  height: 100,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 100,
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sesudah',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Kondisi unit
                _buildSurveyRow(
                  'Kondisi Unit',
                  report.kondisiLabel,
                  valueColor: report.kondisiUnit == 'rusak'
                      ? Colors.red
                      : report.kondisiUnit == 'kotor'
                      ? Colors.orange
                      : Colors.green,
                ),

                // Bagian bermasalah
                if (report.bagianBermasalah.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Bagian Bermasalah',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: report.bagianBermasalah
                        .map(
                          (b) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              b,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],

                // Catatan
                if ((report.catatan ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildSurveyRow('Catatan Teknisi', report.catatan!),
                ],

                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade100),
                const SizedBox(height: 12),

                // Rekomendasi
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rekomendasi Teknisi',
                        style: TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.rekomendasiLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tombol lanjut / tidak
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _respondingSurvey
                            ? null
                            : () => _respondSurvey('tidak'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Tidak Lanjut',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _respondingSurvey
                            ? null
                            : () => _respondSurvey('lanjut'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: _respondingSurvey
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Lanjut',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurveyRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportFeeConfirmCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_shipping_rounded,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Konfirmasi Biaya Transportasi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  'Biaya Transportasi',
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(order.transportFee),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _confirming
                      ? null
                      : () => _handleTransportFee(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Tolak',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirming
                      ? null
                      : () => _handleTransportFee(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: _confirming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Setuju',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String label, bool checked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: checked ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: checked ? AppTheme.onSurface : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(OrderModel order) {
    Color statusColor;
    IconData statusIcon;
    switch (order.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case 'pending_transport_fee':
        statusColor = Colors.orange;
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'pending_transport_fee_set':
        statusColor = Colors.deepOrange;
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'in_progress':
        statusColor = Colors.purple;
        statusIcon = Icons.build_rounded;
        break;
      case 'survey_in_progress':
        statusColor = Colors.indigo;
        statusIcon = Icons.search_rounded;
        break;
      case 'waiting_customer_response':
        statusColor = Colors.deepPurple;
        statusIcon = Icons.pending_actions_rounded;
        break;
      case 'waiting_confirmation':
        statusColor = Colors.teal;
        statusIcon = Icons.pending_actions_rounded;
        break;
      case 'warranty':
        statusColor = Colors.teal.shade700;
        statusIcon = Icons.shield_rounded;
        break;
      case 'complained':
        statusColor = Colors.orange;
        statusIcon = Icons.warning_rounded;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.task_alt_rounded;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Dibuat ${order.createdAt}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                if (order.isPerbaikan) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      order.isPhase2
                          ? '🔩 Perbaikan — Fase 2'
                          : '🔍 Perbaikan — Survey',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.paymentStatus == 'paid' ? '✓ Lunas' : 'Belum Bayar',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color ?? AppTheme.onSurfaceVariant,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          Text(
            amount < 0
                ? '- ${_formatCurrency(amount.abs())}'
                : _formatCurrency(amount),
            style: TextStyle(
              color: color ?? AppTheme.onSurface,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar() {
    if (_order == null) return null;
    final order = _order!;

    // Bayar sekarang
    if (order.paymentStatus == 'unpaid' &&
        order.status == 'pending' &&
        order.tripayPaymentUrl != null) {
      return _bottomButton(
        label: 'Bayar Sekarang',
        color: AppTheme.primary,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(
              paymentUrl: order.tripayPaymentUrl!,
              orderId: order.id,
            ),
          ),
        ).then((_) => _loadOrder()),
      );
    }

    // Lanjut ke pembayaran
    if (order.paymentStatus == 'unpaid' &&
        order.status == 'pending' &&
        order.tripayPaymentUrl == null &&
        order.tripayReference == null) {
      return _bottomButton(
        label: 'Lanjut ke Pembayaran',
        color: AppTheme.primary,
        onTap: () => Navigator.pushNamed(context, '/payment', arguments: order),
      );
    }

    // Konfirmasi selesai
    if (order.status == 'waiting_confirmation') {
      return _bottomButton(
        label: 'Konfirmasi Selesai',
        color: Colors.green,
        onTap: _confirmOrder,
      );
    }

    // Batalkan
    if (['pending', 'pending_transport_fee'].contains(order.status) &&
        order.paymentStatus == 'unpaid' &&
        order.tripayReference == null) {
      return _bottomButton(
        label: _cancelling ? 'Membatalkan...' : 'Batalkan Pesanan',
        color: Colors.red,
        onTap: _cancelling ? null : _cancelOrder,
      );
    }

    return null;
  }

  Widget _bottomButton({
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

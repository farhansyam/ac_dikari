import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import 'order_detail_screen.dart';

class PesananScreen extends StatefulWidget {
  const PesananScreen({Key? key}) : super(key: key);

  @override
  State<PesananScreen> createState() => _PesananScreenState();
}

class _PesananScreenState extends State<PesananScreen> {
  late OrderService _orderService;
  List<OrderModel> _orders = [];
  bool _loading = true;
  String? _error;
  int? _cancellingOrderId;

  static const _activeStatuses = [
    'pending',
    'pending_transport_fee',
    'pending_transport_fee_set',
    'confirmed',
    'in_progress',
    'survey_in_progress',
    'waiting_customer_response',
    'waiting_confirmation',
    'warranty',
    'complained',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _orderService = OrderService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final orders = await _orderService.getOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders
            .where((o) => _activeStatuses.contains(o.status))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Pesanan?'),
        content: Text(
          'Pesanan #${order.id} akan dibatalkan. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _cancellingOrderId = order.id);
    try {
      await _orderService.cancelOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pesanan #${order.id} berhasil dibatalkan.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _cancellingOrderId = null);
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Pesanan Aktif'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _orders.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildOrderCard(_orders[i]),
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat pesanan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadOrders,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak Ada Pesanan Aktif',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Semua pesanan kamu sudah selesai.',
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/order'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Buat Pesanan Baru'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final isCancelling = _cancellingOrderId == order.id;
    final canCancel =
        order.paymentStatus == 'unpaid' && order.status == 'pending';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      ).then((_) => _loadOrders()),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ─── Header ────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Order #${order.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
            ),

            // ─── Body ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item list
                  ...order.items
                      .take(2)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.ac_unit_rounded,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${item['name']} x${item['quantity']}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (order.items.length > 2)
                    Text(
                      '+${order.items.length - 2} layanan lainnya',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),

                  const SizedBox(height: 10),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const SizedBox(height: 10),

                  // Jadwal + total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 14,
                            color: AppTheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${order.scheduledDate} · ${order.scheduledTime}',
                            style: TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatCurrency(order.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  // ─── Banner belum bayar + tombol batalkan ──
                  if (order.paymentStatus == 'unpaid' &&
                      order.status != 'cancelled') ...[
                    const SizedBox(height: 10),
                    _buildBanner(
                      icon: Icons.payment_rounded,
                      text: 'Belum dibayar',
                      trailing: 'Bayar Sekarang →',
                      color: Colors.orange,
                    ),
                    // Tombol batalkan — hanya saat status masih pending
                    if (canCancel) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isCancelling
                              ? null
                              : () => _cancelOrder(order),
                          icon: isCancelling
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.red.shade400,
                                  ),
                                )
                              : Icon(
                                  Icons.cancel_outlined,
                                  size: 16,
                                  color: Colors.red.shade600,
                                ),
                          label: Text(
                            isCancelling
                                ? 'Membatalkan...'
                                : 'Batalkan Pesanan',
                            style: TextStyle(
                              color: isCancelling
                                  ? Colors.grey
                                  : Colors.red.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isCancelling
                                  ? Colors.grey.shade300
                                  : Colors.red.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // ─── Banner lainnya ───────────────────────
                  if (order.status == 'waiting_customer_response') ...[
                    const SizedBox(height: 10),
                    _buildBanner(
                      icon: Icons.help_rounded,
                      text: 'Hasil survey tersedia · Tap untuk lihat',
                      color: Colors.purple,
                    ),
                  ],
                  if (order.status == 'pending_transport_fee') ...[
                    const SizedBox(height: 10),
                    _buildBanner(
                      icon: Icons.local_shipping_rounded,
                      text: 'Menunggu biaya transportasi dari mitra',
                      color: Colors.orange,
                    ),
                  ],
                  if (order.status == 'pending_transport_fee_set') ...[
                    const SizedBox(height: 10),
                    _buildBanner(
                      icon: Icons.local_shipping_rounded,
                      text: 'Konfirmasi biaya transportasi →',
                      color: Colors.deepOrange,
                    ),
                  ],
                  if (order.status == 'waiting_confirmation') ...[
                    const SizedBox(height: 10),
                    _buildBanner(
                      icon: Icons.check_circle_rounded,
                      text: 'Pekerjaan selesai · Tap untuk konfirmasi',
                      color: Colors.green,
                    ),
                  ],
                  if (order.status == 'warranty') ...[
                    const SizedBox(height: 10),
                    _buildBanner(
                      icon: Icons.shield_rounded,
                      text: 'Masa garansi aktif',
                      color: Colors.teal,
                    ),
                  ],
                  if (order.status == 'complained') ...[
                    const SizedBox(height: 10),
                    _buildBanner(
                      icon: Icons.warning_rounded,
                      text: 'Komplain sedang diproses',
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required String text,
    String? trailing,
    required MaterialColor color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing,
              style: TextStyle(
                color: color.shade700,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    Color bgColor;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.orange.shade700;
        bgColor = Colors.orange.shade50;
        label = 'Menunggu';
        break;
      case 'confirmed':
        color = Colors.blue.shade700;
        bgColor = Colors.blue.shade50;
        label = 'Dikonfirmasi';
        break;
      case 'in_progress':
        color = Colors.purple.shade700;
        bgColor = Colors.purple.shade50;
        label = 'Dikerjakan';
        break;
      case 'waiting_confirmation':
        color = Colors.green.shade700;
        bgColor = Colors.green.shade50;
        label = 'Perlu Konfirmasi';
        break;
      case 'warranty':
        color = Colors.teal.shade700;
        bgColor = Colors.teal.shade50;
        label = 'Masa Garansi';
        break;
      case 'complained':
        color = Colors.orange.shade700;
        bgColor = Colors.orange.shade50;
        label = 'Dikomplain';
        break;
      case 'pending_transport_fee':
        color = Colors.orange.shade700;
        bgColor = Colors.orange.shade50;
        label = 'Tunggu Transport';
        break;
      case 'pending_transport_fee_set':
        color = Colors.deepOrange.shade700;
        bgColor = Colors.deepOrange.shade50;
        label = 'Konfirmasi Transport';
        break;
      case 'survey_in_progress':
        color = Colors.indigo.shade700;
        bgColor = Colors.indigo.shade50;
        label = 'Survei Berlangsung';
        break;
      case 'waiting_customer_response':
        color = Colors.purple.shade700;
        bgColor = Colors.purple.shade50;
        label = 'Menunggu Keputusanmu';
        break;
      default:
        color = Colors.grey.shade700;
        bgColor = Colors.grey.shade50;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

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
  bool _loading = true;
  bool _cancelling = false;

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
      if (!mounted) return;
      setState(() {
        _order = order;
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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _confirmOrder() async {
    try {
      await _orderService.confirmOrder(widget.orderId);
      await _loadOrder();
      if (!mounted) return;
      _showSnackBar('Pesanan dikonfirmasi selesai! Terima kasih.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    }
  }

  String _formatCurrency(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $formatted';
  }

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
        // Status card
        _buildStatusCard(order),
        const SizedBox(height: 16),

        // Layanan
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
                              '${item['quantity']} unit AC · ${_formatCurrency((item['unit_price'] as num).toDouble())} / unit',
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

        // Jadwal
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

        // Kontak
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

        // Alamat
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

        // Mitra
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
              Text(
                order.bpName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
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
      case 'confirmed':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'in_progress':
        statusColor = Colors.purple;
        statusIcon = Icons.build_rounded;
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
              ],
            ),
          ),
          // Payment status badge
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

    // Belum bayar → tombol bayar
    if (order.paymentStatus == 'unpaid' &&
        order.status != 'cancelled' &&
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

    // Bisa dibatalkan
    if (order.status == 'waiting_confirmation') {
      return _bottomButton(
        label: 'Konfirmasi Selesai',
        color: Colors.green,
        onTap: _confirmOrder,
      );
    }
    if (order.status == 'pending' &&
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

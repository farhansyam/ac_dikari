import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import 'order_detail_screen.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({Key? key}) : super(key: key);

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late OrderService _orderService;
  List<OrderModel> _orders = [];
  bool _loading = true;
  String? _error;

  // ─── Search & Filter ──────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _timeFilter = 'all'; // all | month | 3months

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final auth = context.read<AuthService>();
    _orderService = OrderService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
            .where((o) => o.status == 'completed' || o.status == 'cancelled')
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

  List<OrderModel> _filteredOrders(String status) {
    var result = _orders.where((o) => o.status == status).toList();

    // ─── Filter waktu ─────────────────────────────────────
    if (_timeFilter != 'all') {
      final now = DateTime.now();
      final cutoff = _timeFilter == 'month'
          ? DateTime(now.year, now.month, 1)
          : now.subtract(const Duration(days: 90));

      result = result.where((o) {
        try {
          final date = DateTime.parse(o.scheduledDate);
          return date.isAfter(cutoff);
        } catch (_) {
          return true;
        }
      }).toList();
    }

    // ─── Filter search ────────────────────────────────────
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((o) {
        // Cari berdasarkan ID order
        if (o.id.toString().contains(q)) return true;
        // Cari berdasarkan nama layanan
        return o.items.any(
          (item) => (item['name'] as String? ?? '').toLowerCase().contains(q),
        );
      }).toList();
    }

    return result;
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _searchQuery = '');
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
        title: const Text('Riwayat'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.onSurfaceVariant,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Selesai'),
            Tab(text: 'Dibatalkan'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : Column(
              children: [
                _buildSearchAndFilter(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList('completed'),
                      _buildList('cancelled'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Search bar + filter chips ─────────────────────────────
  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Cari order ID atau nama layanan...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: _clearSearch,
                      child: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Filter chips
          Row(
            children: [
              _buildFilterChip('Semua', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Bulan Ini', 'month'),
              const SizedBox(width: 8),
              _buildFilterChip('3 Bulan', '3months'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _timeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _timeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
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
            Text(
              'Gagal memuat riwayat',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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

  Widget _buildList(String status) {
    final orders = _filteredOrders(status);

    if (orders.isEmpty) {
      // Beda pesan kalau kosong karena search/filter atau memang kosong
      final isFiltering = _searchQuery.isNotEmpty || _timeFilter != 'all';
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
              child: Icon(
                isFiltering
                    ? Icons.search_off_rounded
                    : status == 'completed'
                    ? Icons.task_alt_rounded
                    : Icons.cancel_outlined,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltering
                  ? 'Tidak ada hasil ditemukan'
                  : status == 'completed'
                  ? 'Belum Ada Riwayat Selesai'
                  : 'Belum Ada Pesanan Dibatalkan',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (isFiltering) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _clearSearch();
                  setState(() => _timeFilter = 'all');
                },
                child: const Text('Reset Pencarian'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _buildOrderCard(orders[index]),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final isCompleted = order.status == 'completed';
    final statusColor = isCompleted ? Colors.green : Colors.red;

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
            // Header
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
                      Icon(
                        isCompleted
                            ? Icons.task_alt_rounded
                            : Icons.cancel_rounded,
                        size: 16,
                        color: statusColor,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCompleted ? 'Selesai' : 'Dibatalkan',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            order.scheduledDate,
                            style: TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatCurrency(order.totalAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? AppTheme.primary : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (isCompleted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/order'),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Pesan Lagi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
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
}

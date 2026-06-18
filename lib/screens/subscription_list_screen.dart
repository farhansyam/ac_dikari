import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import 'subscription_detail_screen.dart';

class SubscriptionListScreen extends StatefulWidget {
  const SubscriptionListScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionListScreen> createState() => _SubscriptionListScreenState();
}

class _SubscriptionListScreenState extends State<SubscriptionListScreen> {
  late SubscriptionService _subService;
  List<SubscriptionModel> _subscriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _subService = SubscriptionService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final subs = await _subService.index();
      if (!mounted) return;
      setState(() {
        _subscriptions = subs;
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('=== SUBSCRIPTION LIST ERROR: $e');
      debugPrint('=== STACK: $stack');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmt(double amount) =>
      'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Cuci Langganan'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => Navigator.pushNamed(
              context,
              '/langganan-baru',
            ).then((_) => _load()),
            tooltip: 'Langganan Baru',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subscriptions.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _subscriptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildCard(_subscriptions[i]),
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
              Icons.calendar_month_rounded,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Langganan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Daftar langganan cuci AC untuk harga lebih hemat.',
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              '/langganan-baru',
            ).then((_) => _load()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Mulai Langganan'),
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

  Widget _buildCard(SubscriptionModel sub) {
    final typeColor = _packageColor(sub.packageType);
    final progressPct = sub.totalSessions > 0
        ? sub.completedSessions / sub.totalSessions
        : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubscriptionDetailScreen(subscriptionId: sub.id),
        ),
      ).then((_) => _load()),
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
            // Header berwarna
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: typeColor.withOpacity(0.15)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _packageIcon(sub.packageType),
                      color: typeColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.packageName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${sub.intervalMonths} bulan sekali · ${sub.totalSessions}× / tahun',
                          style: TextStyle(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(sub.status, sub.paymentStatus),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress sesi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress Sesi',
                        style: TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${sub.completedSessions}/${sub.totalSessions} selesai',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressPct.toDouble(),
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(sub.totalAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                      Text(
                        '/ tahun',
                        style: TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Sesi selanjutnya
                  if (sub.nextSession != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: typeColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: typeColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sesi ke-${sub.nextSession!.sessionNumber}: '
                            '${sub.nextSession!.scheduledDate} ${sub.nextSession!.scheduledTime}',
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Banner belum bayar
                  if (!sub.isPaid && sub.status == 'pending') ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.payment_rounded,
                            size: 14,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Belum dibayar · Tap untuk bayar',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Banner perlu atur jadwal
                  if (sub.isPaid && sub.sessions.isEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Atur jadwal cuci kamu →',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  Widget _statusChip(String status, String paymentStatus) {
    Color color;
    Color bgColor;
    String label;
    if (paymentStatus == 'unpaid') {
      color = Colors.orange.shade700;
      bgColor = Colors.orange.shade50;
      label = 'Belum Bayar';
    } else {
      switch (status) {
        case 'active':
          color = Colors.green.shade700;
          bgColor = Colors.green.shade50;
          label = 'Aktif';
          break;
        case 'completed':
          color = Colors.blue.shade700;
          bgColor = Colors.blue.shade50;
          label = 'Selesai';
          break;
        case 'cancelled':
          color = Colors.red.shade700;
          bgColor = Colors.red.shade50;
          label = 'Dibatalkan';
          break;
        default:
          color = Colors.grey.shade700;
          bgColor = Colors.grey.shade50;
          label = status;
      }
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

  Color _packageColor(String type) {
    switch (type) {
      case 'hemat':
        return Colors.blue;
      case 'rutin':
        return Colors.orange;
      case 'intensif':
        return Colors.red;
      default:
        return AppTheme.primary;
    }
  }

  IconData _packageIcon(String type) {
    switch (type) {
      case 'hemat':
        return Icons.water_drop_rounded;
      case 'rutin':
        return Icons.autorenew_rounded;
      case 'intensif':
        return Icons.bolt_rounded;
      default:
        return Icons.card_membership_rounded;
    }
  }
}

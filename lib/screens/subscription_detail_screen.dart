import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import 'payment_webview_screen.dart';
import 'subscription_flow_screen.dart';

class SubscriptionDetailScreen extends StatefulWidget {
  final int subscriptionId;
  const SubscriptionDetailScreen({Key? key, required this.subscriptionId})
    : super(key: key);

  @override
  State<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen> {
  late SubscriptionService _subService;
  SubscriptionModel? _sub;
  bool _loading = true;
  bool _confirming = false;

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
      final sub = await _subService.show(widget.subscriptionId);
      if (!mounted) return;
      setState(() {
        _sub = sub;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  Future<void> _confirmSession(SubscriptionSessionModel session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Selesai?'),
        content: Text(
          'Konfirmasi bahwa sesi ke-${session.sessionNumber} sudah selesai dikerjakan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Selesai'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _confirming = true);
    try {
      await _subService.confirmSession(
        subscriptionId: widget.subscriptionId,
        sessionId: session.id,
      );
      await _load();
      if (!mounted) return;
      _snack('Sesi ke-${session.sessionNumber} dikonfirmasi!');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  String _fmt(double amount) =>
      'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(
          _sub != null ? 'Langganan #${_sub!.id}' : 'Detail Langganan',
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sub == null
          ? const Center(child: Text('Gagal memuat data.'))
          : RefreshIndicator(onRefresh: _load, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    final sub = _sub!;
    final typeColor = _packageColor(sub.packageType);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─── Status Card ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [typeColor, typeColor.withOpacity(0.7)],
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
                child: Icon(
                  _packageIcon(sub.packageType),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.packageName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${sub.intervalMonths} bulan sekali · ${sub.totalSessions}× / tahun',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sub.statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmt(sub.totalAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '/ tahun',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Banner bayar / atur jadwal ───────────────────────
        if (!sub.isPaid && sub.tripayPaymentUrl != null) ...[
          _buildBanner(
            icon: Icons.payment_rounded,
            text: 'Langganan belum dibayar. Tap untuk melanjutkan pembayaran.',
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentWebViewScreen(
                  paymentUrl: sub.tripayPaymentUrl!,
                  orderId: sub.id,
                ),
              ),
            ).then((_) => _load()),
          ),
          const SizedBox(height: 12),
        ],

        if (sub.isPaid && sub.sessions.isEmpty) ...[
          _buildBanner(
            icon: Icons.calendar_today_rounded,
            text: 'Pembayaran berhasil! Sekarang atur jadwal cuci kamu.',
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _ScheduleSetupScreen(
                  subscription: sub,
                  subService: _subService,
                ),
              ),
            ).then((_) => _load()),
          ),
          const SizedBox(height: 12),
        ],

        // ─── Progress sesi ────────────────────────────────────
        _buildSection(
          title: 'Progress Sesi',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${sub.completedSessions} dari ${sub.totalSessions} sesi selesai',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${((sub.completedSessions / (sub.totalSessions > 0 ? sub.totalSessions : 1)) * 100).round()}%',
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: sub.totalSessions > 0
                      ? sub.completedSessions / sub.totalSessions
                      : 0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Info pembayaran ──────────────────────────────────
        _buildSection(
          title: 'Pembayaran',
          child: Column(
            children: [
              _infoRow('Subtotal', _fmt(sub.subtotal)),
              if (sub.discountAmount > 0)
                _infoRow(
                  'Diskon',
                  '- ${_fmt(sub.discountAmount)}',
                  valueColor: Colors.green.shade600,
                ),
              _infoRow(
                'Total Bayar',
                _fmt(sub.totalAmount),
                isBold: true,
                valueColor: typeColor,
              ),
              _infoRow(
                'Status',
                sub.isPaid ? '✓ Lunas' : 'Belum Bayar',
                valueColor: sub.isPaid
                    ? Colors.green.shade600
                    : Colors.orange.shade700,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Jadwal sesi ──────────────────────────────────────
        if (sub.sessions.isNotEmpty) ...[
          _buildSection(
            title: 'Jadwal Sesi',
            child: Column(
              children: sub.sessions
                  .map((session) => _buildSessionCard(session, sub.id))
                  .toList(),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ],
    );
  }

  Widget _buildSessionCard(SubscriptionSessionModel session, int subId) {
    Color statusColor;
    Color statusBg;
    switch (session.status) {
      case 'scheduled':
        statusColor = Colors.grey.shade700;
        statusBg = Colors.grey.shade100;
        break;
      case 'confirmed':
        statusColor = Colors.blue.shade700;
        statusBg = Colors.blue.shade50;
        break;
      case 'in_progress':
        statusColor = Colors.orange.shade700;
        statusBg = Colors.orange.shade50;
        break;
      case 'waiting_confirmation':
        statusColor = Colors.purple.shade700;
        statusBg = Colors.purple.shade50;
        break;
      case 'completed':
        statusColor = Colors.green.shade700;
        statusBg = Colors.green.shade50;
        break;
      default:
        statusColor = Colors.grey.shade700;
        statusBg = Colors.grey.shade100;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: session.canConfirm
              ? Colors.purple.shade300
              : Colors.grey.shade200,
          width: session.canConfirm ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: session.isCompleted
                      ? Colors.green
                      : AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: session.isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                      : Text(
                          '${session.sessionNumber}',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sesi ke-${session.sessionNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          // ← wrap ini
                          child: Text(
                            '${session.scheduledDate} · ${session.scheduledTime}',
                            style: TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  session.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Teknisi
          if (session.technician != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person_rounded,
                  size: 14,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  // ← wrap ini
                  child: Text(
                    'Teknisi: ${session.technician!['user']?['name'] ?? '-'}',
                    style: TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Tombol konfirmasi
          if (session.canConfirm) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirming ? null : () => _confirmSession(session),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  _confirming ? 'Mengkonfirmasi...' : 'Konfirmasi Selesai',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
              ),
            ),
          ],

          // Laporan
          if (session.report != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      session.report!['photo_before'] ?? '',
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      session.report!['photo_after'] ?? '',
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...{
              'filter_cleaned': 'Filter dibersihkan',
              'freon_checked': 'Freon dicek',
              'drain_cleaned': 'Saluran air dibersihkan',
              'electrical_checked': 'Kelistrikan dicek',
            }.entries.map((e) {
              final checked = session.report![e.key] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      checked
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 16,
                      color: checked ? Colors.green : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: checked ? Colors.black87 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if ((session.report!['notes'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.report!['notes'].toString(),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
          ],
        ),
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
            blurRadius: 8,
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

  Widget _infoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 15 : 13,
              color: valueColor ?? AppTheme.onSurface,
            ),
          ),
        ],
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
        return Icons.savings_rounded;
      case 'rutin':
        return Icons.calendar_month_rounded;
      case 'intensif':
        return Icons.bolt_rounded;
      default:
        return Icons.card_membership_rounded;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

// ─── Screen atur jadwal (setelah bayar) ──────────────────────────

class _ScheduleSetupScreen extends StatefulWidget {
  final SubscriptionModel subscription;
  final SubscriptionService subService;
  const _ScheduleSetupScreen({
    required this.subscription,
    required this.subService,
  });

  @override
  State<_ScheduleSetupScreen> createState() => _ScheduleSetupScreenState();
}

class _ScheduleSetupScreenState extends State<_ScheduleSetupScreen> {
  late List<DateTime?> _dates;
  late List<String?> _times;
  bool _saving = false;

  static const List<String> _timeSlots = [
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
  ];

  @override
  void initState() {
    super.initState();
    final n = widget.subscription.totalSessions;
    _dates = List.filled(n, null);
    _times = List.filled(n, null);
  }

  Future<void> _save() async {
    for (int i = 0; i < widget.subscription.totalSessions; i++) {
      if (_dates[i] == null || _times[i] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lengkapi jadwal untuk semua sesi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final schedules = List.generate(
        widget.subscription.totalSessions,
        (i) => {
          'session_number': i + 1,
          'scheduled_date':
              '${_dates[i]!.year}-${_dates[i]!.month.toString().padLeft(2, '0')}-${_dates[i]!.day.toString().padLeft(2, '0')}',
          'scheduled_time': _times[i],
        },
      );

      await widget.subService.setSchedule(
        subscriptionId: widget.subscription.id,
        schedules: schedules,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Atur Jadwal'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Atur ${sub.totalSessions} jadwal cuci AC kamu. '
                    'Sesi berikutnya otomatis berjarak ${sub.intervalMonths} bulan.',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(
            sub.totalSessions,
            (i) => _buildSlot(i, sub.intervalMonths),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        color: Colors.white,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Simpan Jadwal',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlot(int i, int intervalMonths) {
    final date = _dates[i];
    final time = _times[i];

    DateTime? minDate;
    DateTime? maxDate;
    if (i > 0 && _dates[0] != null) {
      final base = _dates[0]!;
      final center = base.add(Duration(days: i * intervalMonths * 30));
      minDate = center.subtract(const Duration(days: 7));
      maxDate = center.add(const Duration(days: 7));
    } else {
      minDate = DateTime.now();
      maxDate = DateTime.now().add(const Duration(days: 365));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: date != null && time != null
              ? AppTheme.primary
              : Colors.grey.shade200,
          width: date != null && time != null ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: date != null ? AppTheme.primary : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: date != null ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sesi ke-${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date ?? minDate!,
                firstDate: minDate!,
                lastDate: maxDate!,
                locale: const Locale('id', 'ID'),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.light(primary: AppTheme.primary),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _dates[i] = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: date != null ? AppTheme.primary : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: date != null
                        ? AppTheme.primary
                        : Colors.grey.shade400,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Pilih tanggal',
                    style: TextStyle(
                      color: date != null
                          ? AppTheme.onSurface
                          : Colors.grey.shade400,
                      fontWeight: date != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _timeSlots.map((slot) {
              final isSelected = time == slot;
              return GestureDetector(
                onTap: () => setState(() => _times[i] = slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/dikaripay_service.dart';
import '../services/payment_service.dart';
import 'payment_webview_screen.dart';

class DikariPayScreen extends StatefulWidget {
  const DikariPayScreen({Key? key}) : super(key: key);

  @override
  State<DikariPayScreen> createState() => _DikariPayScreenState();
}

class _DikariPayScreenState extends State<DikariPayScreen> {
  late DikariPayService _dikariPayService;
  late PaymentService _paymentService;

  double _balance = 0;
  List<DikariPayTransaction> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _dikariPayService = DikariPayService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _paymentService = PaymentService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      setState(() => _loading = true);
      final data = await _dikariPayService.getBalance();
      if (!mounted) return;
      setState(() {
        _balance = data['balance'] as double;
        _transactions = data['transactions'] as List<DikariPayTransaction>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar(e.toString());
    }
  }

  void _showTopupSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopupSheet(
        dikariPayService: _dikariPayService,
        paymentService: _paymentService,
      ),
    );
    if (result == true) await _loadBalance();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('DikariPay'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBalance,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── Kartu saldo ─────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF1976D2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SALDO DIKARIPAY',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatCurrency(_balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showTopupSheet,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Isi Saldo',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Riwayat transaksi ────────────────────
                  Text(
                    'Riwayat Transaksi',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'Belum ada transaksi',
                          style: TextStyle(color: AppTheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    Container(
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
                        children: _transactions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final tx = entry.value;
                          return Column(
                            children: [
                              _buildTransactionItem(tx),
                              if (index < _transactions.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 16,
                                  color: Colors.grey.shade100,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTransactionItem(DikariPayTransaction tx) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tx.isCredit ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              tx.isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: tx.isCredit ? Colors.green.shade600 : Colors.red.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? tx.typeLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  tx.createdAt,
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tx.isCredit ? '+' : '-'} ${_formatCurrency(tx.amount)}',
                style: TextStyle(
                  color: tx.isCredit
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                _formatCurrency(tx.balanceAfter),
                style: TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet Topup ───────────────────────────────────────────

class _TopupSheet extends StatefulWidget {
  final DikariPayService dikariPayService;
  final PaymentService paymentService;

  const _TopupSheet({
    required this.dikariPayService,
    required this.paymentService,
  });

  @override
  State<_TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<_TopupSheet> {
  final _amountCtrl = TextEditingController();
  List<PaymentChannel> _channels = [];
  PaymentChannel? _selectedChannel;
  bool _loadingChannels = true;
  bool _processing = false;

  // Inline error state — tidak pakai SnackBar dari dalam sheet
  String? _amountError;
  String? _channelError;

  final List<int> _quickAmounts = [10000, 20000, 50000, 100000, 200000, 500000];

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    try {
      final channels = await widget.paymentService.getChannels();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _loadingChannels = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingChannels = false);
    }
  }

  /// Validasi nominal — return pesan error, atau null jika valid
  String? _validateAmount(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return 'Nominal tidak boleh kosong';
    // Cegah leading zero (misal "010000")
    if (cleaned.length > 1 && cleaned.startsWith('0')) {
      return 'Nominal tidak valid';
    }
    final amount = int.tryParse(cleaned);
    if (amount == null || amount == 0) return 'Masukkan nominal yang valid';
    if (amount < 10000) return 'Minimum topup Rp 10.000';
    return null;
  }

  Future<void> _topup() async {
    // ── Validasi nominal inline ──
    final amountErr = _validateAmount(_amountCtrl.text);
    if (amountErr != null) {
      setState(() => _amountError = amountErr);
      return;
    }

    // ── Validasi metode pembayaran inline ──
    if (_selectedChannel == null) {
      setState(() => _channelError = 'Pilih metode pembayaran terlebih dahulu');
      return;
    }

    setState(() {
      _amountError = null;
      _channelError = null;
      _processing = true;
    });

    try {
      final amount = int.parse(_amountCtrl.text.trim());

      final result = await widget.dikariPayService.topup(
        amount: amount,
        paymentMethod: _selectedChannel!.code,
      );

      if (!mounted) return;
      setState(() => _processing = false);

      final paymentUrl = result['payment_url'] as String?;
      if (paymentUrl != null) {
        // Push PaymentWebView langsung dari context sheet — sheet ada di background
        // Saat PaymentWebView selesai, baru pop sheet dengan hasilnya
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PaymentWebViewScreen(paymentUrl: paymentUrl, orderId: 0),
          ),
        );
        if (!mounted) return;
        // Pop sheet — true = bayar sukses, false = belum bayar
        Navigator.of(context).pop(paid == true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDisplay(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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
            const SizedBox(height: 20),
            Text(
              'Isi Saldo DikariPay',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ─── Input nominal ────────────────────────────
            Text(
              'Nominal',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              // Hanya angka — tidak boleh huruf atau karakter lain
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (val) {
                // Validasi real-time — error langsung muncul/hilang saat ketik
                setState(() => _amountError = _validateAmount(val));
              },
              decoration: InputDecoration(
                hintText: 'Masukkan nominal topup',
                prefixText: 'Rp ',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: _amountError != null
                    ? Colors.red.shade50
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _amountError != null
                        ? Colors.red.shade300
                        : Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _amountError != null
                        ? Colors.red.shade400
                        : AppTheme.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade300),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                errorText: _amountError,
              ),
            ),
            const SizedBox(height: 12),

            // ─── Quick amounts ────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickAmounts.map((amount) {
                return GestureDetector(
                  onTap: () => setState(() {
                    _amountCtrl.text = amount.toString();
                    _amountError = null; // nominal cepat selalu valid
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      'Rp ${_formatDisplay(amount)}',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ─── Metode pembayaran ────────────────────────
            Text(
              'Metode Pembayaran',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingChannels)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<PaymentChannel>(
                value: _selectedChannel,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _channelError != null
                      ? Colors.red.shade50
                      : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _channelError != null
                          ? Colors.red.shade300
                          : Colors.grey.shade200,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _channelError != null
                          ? Colors.red.shade400
                          : AppTheme.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  errorText: _channelError,
                ),
                hint: Text(
                  'Pilih metode',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
                items: _channels
                    .map(
                      (ch) => DropdownMenuItem(
                        value: ch,
                        child: Text(ch.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (ch) => setState(() {
                  _selectedChannel = ch;
                  _channelError = null; // hapus error saat dipilih
                }),
              ),
            const SizedBox(height: 24),

            // ─── Tombol lanjut bayar ──────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processing ? null : _topup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _processing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Lanjut Bayar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

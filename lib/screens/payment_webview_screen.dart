import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final int orderId; // 0 = topup DikariPay

  const PaymentWebViewScreen({
    Key? key,
    required this.paymentUrl,
    required this.orderId,
  }) : super(key: key);

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen>
    with WidgetsBindingObserver {
  bool _browserOpened = false;
  bool _checking = false;
  bool _hasChecked = false;
  double _initialBalance = 0;

  bool get _isTopup => widget.orderId == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openBrowser());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _browserOpened &&
        !_checking &&
        !_hasChecked) {
      _hasChecked = true;
      _checkPaymentStatus();
    }
  }

  Future<void> _openBrowser() async {
    // Simpan saldo awal sebelum buka browser (khusus topup)
    if (_isTopup) {
      try {
        final token = await const FlutterSecureStorage().read(
          key: 'auth_token',
        );
        if (token != null) {
          final res = await http
              .get(
                Uri.parse('${AuthService.baseUrl}/dikaripay/balance'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            _initialBalance = (data['balance'] as num).toDouble();
          }
        }
      } catch (_) {}
    }

    final uri = Uri.parse(widget.paymentUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() => _browserOpened = true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Tidak bisa membuka browser: $e');
    }
  }

  Future<void> _checkPaymentStatus() async {
    if (!mounted) return;
    setState(() => _checking = true);

    try {
      final token = await const FlutterSecureStorage().read(key: 'auth_token');
      if (token == null) {
        if (!mounted) return;
        setState(() => _checking = false);
        return;
      }

      if (_isTopup) {
        final response = await http
            .get(
              Uri.parse('${AuthService.baseUrl}/dikaripay/balance'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 5));

        if (!mounted) return;
        setState(() => _checking = false);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final newBalance = (data['balance'] as num).toDouble();
          // Sukses hanya kalau saldo bertambah dari saldo awal
          _showResultDialog(newBalance > _initialBalance, isTopup: true);
        }
      } else {
        final response = await http
            .get(
              Uri.parse('${AuthService.baseUrl}/orders/${widget.orderId}'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 5));

        if (!mounted) return;
        setState(() => _checking = false);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final paymentStatus = data['order']['payment_status'] as String?;
          _showResultDialog(paymentStatus == 'paid', isTopup: false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      _showResultDialog(false, isTopup: _isTopup);
    }
  }

  void _showResultDialog(bool success, {required bool isTopup}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: success ? Colors.green.shade50 : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                success
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_empty_rounded,
                color: success ? Colors.green.shade500 : Colors.orange.shade500,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              success
                  ? (isTopup ? 'Topup Berhasil!' : 'Pembayaran Berhasil!')
                  : 'Menunggu Pembayaran',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              success
                  ? (isTopup
                        ? 'Saldo DikariPay kamu sudah bertambah.'
                        : 'Pesanan kamu sedang diproses.')
                  : 'Pembayaran belum kami terima. Cek status di menu Pesanan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // tutup dialog
                Navigator.of(dialogContext).pop(); // tutup payment screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Kembali ke Beranda',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(_isTopup ? 'Topup DikariPay' : 'Pembayaran'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_browser_rounded,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _browserOpened
                    ? 'Selesaikan Pembayaran di Browser'
                    : 'Membuka Browser...',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _browserOpened
                    ? 'Setelah selesai bayar, kembali ke app ini untuk melihat status pembayaran.'
                    : 'Harap tunggu sebentar...',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (_browserOpened) ...[
                OutlinedButton.icon(
                  onPressed: _openBrowser,
                  icon: const Icon(Icons.launch_rounded, size: 18),
                  label: const Text('Buka Browser Lagi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _checking
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: () {
                          setState(() => _hasChecked = false);
                          _checkPaymentStatus();
                        },
                        child: const Text('Sudah Bayar? Cek Status'),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

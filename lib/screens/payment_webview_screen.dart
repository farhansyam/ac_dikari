import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final int orderId;

  const PaymentWebViewScreen({
    Key? key,
    required this.paymentUrl,
    required this.orderId,
  }) : super(key: key);

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _loading = false);
            _checkPaymentStatus(url);
          },
          onNavigationRequest: (request) {
            // Cek kalau redirect ke return_url (payment selesai)
            if (_isReturnUrl(request.url)) {
              _handlePaymentComplete(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  bool _isReturnUrl(String url) {
    // Sesuaikan dengan TRIPAY_RETURN_URL di .env
    return url.contains('dikari.id/payment/return') ||
        url.contains('payment/return') ||
        url.contains('payment/success') ||
        url.contains('payment/failed');
  }

  void _checkPaymentStatus(String url) {
    if (_isReturnUrl(url)) {
      _handlePaymentComplete(url);
    }
  }

  void _handlePaymentComplete(String url) {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/pesanan',
      (route) => route.settings.name == '/home',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          // Tombol refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primary,
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          // Banner info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.primary.withOpacity(0.08),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Pembayaran aman & terenkripsi oleh Tripay',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // WebView
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}

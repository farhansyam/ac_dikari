import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/address_service.dart';
import '../services/phone_service.dart';
import '../services/subscription_service.dart';
import '../services/payment_service.dart';
import '../services/dikaripay_service.dart';
import 'payment_webview_screen.dart';

class SubscriptionFlowScreen extends StatefulWidget {
  const SubscriptionFlowScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionFlowScreen> createState() => _SubscriptionFlowScreenState();
}

class _SubscriptionFlowScreenState extends State<SubscriptionFlowScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;
  // Step 0: Alamat & Kontak
  // Step 1: Pilih Paket
  // Step 2: Pilih Service
  // Step 3: Atur Jadwal
  // Step 4: Preview & Bayar

  late SubscriptionService _subService;
  late AddressService _addressService;
  late PhoneService _phoneService;
  late PaymentService _paymentService;
  late DikariPayService _dikariPayService;

  // Step 0
  List<AddressModel> _addresses = [];
  List<PhoneModel> _phones = [];
  AddressModel? _selectedAddress;
  PhoneModel? _selectedPhone;
  bool _loadingStep0 = true;

  // Step 1
  List<SubscriptionPackageModel> _packages = [];
  SubscriptionPackageModel? _selectedPackage;
  bool _loadingPackages = false;
  double _minBasePrice = 0; // harga minimum layanan di area customer

  // Step 2
  List<SubscriptionServiceItem> _services = [];
  Map<int, SubscriptionServiceItem> _selectedServices = {};
  int? _bpId;
  String? _bpName;
  bool _loadingServices = false;

  // Step 3
  SubscriptionPreview? _preview;
  List<PaymentChannel> _paymentChannels = [];
  Map<String, List<PaymentChannel>> _groupedChannels = {};
  PaymentChannel? _selectedChannel;
  bool _useDikariPay = false;
  double _dikariPayBalance = 0;
  final _couponCtrl = TextEditingController();
  CouponResult? _couponResult;
  bool _couponError = false;
  String? _couponErrorMsg;
  bool _validatingCoupon = false;
  bool _loadingPreview = false;
  bool _submitting = false;
  SubscriptionModel? _createdSubscription;

  // Step 4 — Jadwal
  List<DateTime?> _scheduleDates = [];
  List<String?> _scheduleTimes = [];
  bool _savingSchedule = false;

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
    final auth = context.read<AuthService>();
    _subService = SubscriptionService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _addressService = AddressService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _phoneService = PhoneService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _paymentService = PaymentService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _dikariPayService = DikariPayService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _loadStep0();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  // ─── Loaders ──────────────────────────────────────────────────

  Future<void> _loadStep0() async {
    setState(() => _loadingStep0 = true);
    try {
      final results = await Future.wait([
        _phoneService.getPhones(),
        _addressService.getAddresses(),
      ]);
      final phones = results[0] as List<PhoneModel>;
      final addresses = results[1] as List<AddressModel>;
      if (!mounted) return;
      setState(() {
        _phones = phones;
        _addresses = addresses;
        _selectedPhone = phones.firstWhere(
          (p) => p.isPrimary,
          orElse: () => phones.isNotEmpty ? phones.first : _selectedPhone!,
        );
        _selectedAddress = addresses.firstWhere(
          (a) => a.isPrimary,
          orElse: () =>
              addresses.isNotEmpty ? addresses.first : _selectedAddress!,
        );
        _loadingStep0 = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStep0 = false);
    }
  }

  /// Load packages + services sekaligus (parallel).
  /// Services di-load di sini supaya harga estimasi bisa ditampilkan
  /// langsung di step 1 (pilih paket), sebelum user masuk step 2.
  Future<void> _loadPackages() async {
    if (_packages.isNotEmpty) return;
    setState(() => _loadingPackages = true);
    try {
      final results = await Future.wait([
        _subService.getPackages(),
        _subService.getServices(_selectedAddress!.id),
      ]);

      final pkgs = results[0] as List<SubscriptionPackageModel>;
      final servicesData = results[1] as Map<String, dynamic>;
      final svcs = servicesData['services'] as List<SubscriptionServiceItem>;

      double minPrice = 0;
      if (svcs.isNotEmpty) {
        minPrice = svcs.map((s) => s.basePrice).reduce((a, b) => a < b ? a : b);
      }

      if (!mounted) return;
      setState(() {
        _packages = pkgs;
        _bpId = servicesData['bp_id'];
        _bpName = servicesData['bp_name'];
        _services = svcs;
        _minBasePrice = minPrice;
        _loadingPackages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPackages = false);
      _snack(e.toString());
    }
  }

  Future<void> _loadServices() async {
    if (_selectedAddress == null) return;
    // Services sudah di-load parallel di _loadPackages — skip reload
    if (_services.isNotEmpty && _bpId != null) return;

    setState(() {
      _loadingServices = true;
      _services = [];
      _selectedServices = {};
    });
    try {
      final result = await _subService.getServices(_selectedAddress!.id);
      if (!mounted) return;
      setState(() {
        _bpId = result['bp_id'];
        _bpName = result['bp_name'];
        _services = result['services'] as List<SubscriptionServiceItem>;
        _loadingServices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingServices = false);
      _snack(e.toString());
    }
  }

  Future<void> _loadPreviewAndChannels() async {
    if (_selectedPackage == null || _selectedServices.isEmpty) return;
    setState(() => _loadingPreview = true);
    try {
      final items = _selectedServices.values
          .map((s) => {'bp_service_id': s.bpServiceId, 'quantity': s.quantity})
          .toList();

      final results = await Future.wait([
        _subService.preview(
          packageId: _selectedPackage!.id,
          addressId: _selectedAddress!.id,
          items: items,
          package: _selectedPackage!,
        ),
        _paymentService.getChannels(),
        _dikariPayService.getBalance(),
      ]);

      if (!mounted) return;
      final channels = results[1] as List<PaymentChannel>;
      final grouped = <String, List<PaymentChannel>>{};
      for (final ch in channels) {
        grouped.putIfAbsent(ch.group, () => []).add(ch);
      }
      final balanceData = results[2] as Map<String, dynamic>;

      setState(() {
        _preview = results[0] as SubscriptionPreview;
        _paymentChannels = channels;
        _groupedChannels = grouped;
        _dikariPayBalance = balanceData['balance'] as double;
        _loadingPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPreview = false);
      _snack(e.toString());
    }
  }

  // ─── Navigation ───────────────────────────────────────────────

  void _next() {
    switch (_currentStep) {
      case 0:
        if (_selectedPhone == null || _selectedAddress == null) {
          _snack('Pilih nomor kontak dan alamat terlebih dahulu.');
          return;
        }
        _loadPackages();
        break;
      case 1:
        if (_selectedPackage == null) {
          _snack('Pilih paket terlebih dahulu.');
          return;
        }
        _loadServices();
        break;
      case 2:
        if (_selectedServices.isEmpty) {
          _snack('Pilih minimal satu layanan.');
          return;
        }
        _initScheduleSlots();
        break;
      case 3:
        for (int i = 0; i < (_selectedPackage?.totalSessions ?? 0); i++) {
          if (_scheduleDates[i] == null || _scheduleTimes[i] == null) {
            _snack('Lengkapi jadwal untuk semua sesi.');
            return;
          }
        }
        _loadPreviewAndChannels();
        break;
      case 4:
        if (!_useDikariPay && _selectedChannel == null) {
          _snack('Pilih metode pembayaran.');
          return;
        }
        _submitSubscription();
        return;
    }
    _goToStep(_currentStep + 1);
  }

  void _prev() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      Navigator.pop(context);
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ─── Submit ───────────────────────────────────────────────────

  Future<void> _submitSubscription() async {
    setState(() => _submitting = true);
    try {
      final items = _selectedServices.values
          .map((s) => {'bp_service_id': s.bpServiceId, 'quantity': s.quantity})
          .toList();

      final paymentMethod = _useDikariPay
          ? 'DIKARIPAY'
          : _selectedChannel!.code;

      final sub = await _subService.store(
        packageId: _selectedPackage!.id,
        addressId: _selectedAddress!.id,
        userPhoneId: _selectedPhone!.id,
        items: items,
        paymentMethod: paymentMethod,
      );

      if (!mounted) return;
      setState(() => _createdSubscription = sub);

      // ─── DikariPay: bayar langsung ────────────────────────
      if (_useDikariPay) {
        await _dikariPayService.paySubscription(subscriptionId: sub.id);
        if (!mounted) return;
        await _saveScheduleAfterPaid(sub.id);
        return;
      }

      // ─── Tripay: buka webview ─────────────────────────────
      setState(() => _submitting = false);
      if (sub.tripayPaymentUrl != null) {
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(
              paymentUrl: sub.tripayPaymentUrl!,
              orderId: sub.id,
            ),
          ),
        );
        if (paid == true && mounted) {
          await _saveScheduleAfterPaid(sub.id);
        } else if (mounted) {
          _snack('Pembayaran belum selesai.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(e.toString());
    }
  }

  Future<void> _saveScheduleAfterPaid(int subscriptionId) async {
    try {
      final schedules = List.generate(
        _selectedPackage!.totalSessions,
        (i) => {
          'session_number': i + 1,
          'scheduled_date': DateFormat('yyyy-MM-dd').format(_scheduleDates[i]!),
          'scheduled_time': _scheduleTimes[i],
        },
      );

      await _subService.setSchedule(
        subscriptionId: subscriptionId,
        schedules: schedules,
      );

      if (!mounted) return;
      setState(() => _submitting = false);
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('Pembayaran berhasil, tapi gagal simpan jadwal: ${e.toString()}');
    }
  }

  // ─── Coupon helpers ───────────────────────────────────────────

  Future<void> _validateCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _validatingCoupon = true;
      _couponError = false;
      _couponErrorMsg = null;
    });
    try {
      final result = await _paymentService.validateCoupon(
        code,
        _preview!.totalAmount,
      );
      if (!mounted) return;
      setState(() {
        _couponResult = result.valid ? result : null;
        _couponError = !result.valid;
        _couponErrorMsg = result.valid ? null : result.message;
        _validatingCoupon = false;
      });
      if (result.valid) _snack(result.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _couponError = true;
        _couponErrorMsg = e.toString();
        _validatingCoupon = false;
      });
    }
  }

  void _removeCoupon() => setState(() {
    _couponResult = null;
    _couponError = false;
    _couponErrorMsg = null;
    _couponCtrl.clear();
  });

  double get _discount => _couponResult?.discountAmount ?? 0;
  double get _grandTotal => (_preview?.totalAmount ?? 0) - _discount;

  void _initScheduleSlots() {
    final n = _selectedPackage!.totalSessions;
    _scheduleDates = List.filled(n, null);
    _scheduleTimes = List.filled(n, null);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade500,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Langganan Berhasil!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Jadwal cuci AC kamu sudah tersimpan.\nTim kami akan segera menghubungi kamu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/langganan');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Lihat Langganan'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _prev,
        ),
        title: Column(
          children: [
            const Text(
              'Cuci Langganan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            _buildStepIndicator(),
          ],
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep0(),
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
          _buildStep4(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_totalSteps, (i) {
        final isActive = i == _currentStep;
        final isDone = i < _currentStep;
        return Row(
          children: [
            if (i > 0)
              Container(
                width: 12,
                height: 2,
                color: isDone ? AppTheme.primary : Colors.grey.shade300,
              ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isDone || isActive
                    ? AppTheme.primary
                    : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 11,
                      )
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey.shade500,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ─── Step 0: Alamat & Kontak ──────────────────────────────────

  Widget _buildStep0() {
    if (_loadingStep0) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoBanner(
          icon: Icons.calendar_month_rounded,
          color: Colors.teal,
          text:
              'Pilih alamat dan nomor telepon untuk layanan cuci AC langganan kamu.',
        ),
        const SizedBox(height: 20),
        _sectionTitle('Nomor Kontak'),
        ..._phones.map(
          (p) => _buildSelectableCard(
            isSelected: _selectedPhone?.id == p.id,
            onTap: () => setState(() => _selectedPhone = p),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.phone_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.label,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (p.isPrimary) ...[
                            const SizedBox(width: 6),
                            _primaryBadge(),
                          ],
                        ],
                      ),
                      Text(
                        p.phoneNumber,
                        style: TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_phones.isEmpty)
          _emptyHint(
            icon: Icons.phone_outlined,
            message: 'Belum ada nomor kontak.',
            actionLabel: 'Tambah',
            onTap: () => Navigator.pushNamed(
              context,
              '/kontak',
            ).then((_) => _loadStep0()),
          ),
        const SizedBox(height: 24),
        _sectionTitle('Alamat Pengerjaan'),
        ..._addresses.map(
          (a) => _buildSelectableCard(
            isSelected: _selectedAddress?.id == a.id,
            onTap: () => setState(() => _selectedAddress = a),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.propertyIcon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            a.label,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (a.isPrimary) ...[
                            const SizedBox(width: 6),
                            _primaryBadge(),
                          ],
                        ],
                      ),
                      Text(
                        a.formattedAddress,
                        style: TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_addresses.isEmpty)
          _emptyHint(
            icon: Icons.location_off_rounded,
            message: 'Belum ada alamat.',
            actionLabel: 'Tambah',
            onTap: () => Navigator.pushNamed(
              context,
              '/alamat',
            ).then((_) => _loadStep0()),
          ),
      ],
    );
  }

  // ─── Step 1: Pilih Paket ──────────────────────────────────────

  Widget _buildStep1() {
    if (_loadingPackages)
      return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoBanner(
          icon: Icons.local_offer_rounded,
          color: Colors.purple,
          text: _minBasePrice > 0
              ? 'Pilih paket yang sesuai kebutuhan. Estimasi harga berdasarkan tarif layanan di area kamu.'
              : 'Pilih paket yang sesuai kebutuhan. Harga mengikuti tarif layanan di area kamu.',
        ),
        const SizedBox(height: 20),
        ..._packages.map((pkg) {
          final isSelected = _selectedPackage?.id == pkg.id;
          final typeColor = _packageColor(pkg.type);
          final estimasiPerTahun =
              _minBasePrice * pkg.priceMultiplier * pkg.totalSessions;
          final normalPerTahun = _minBasePrice * pkg.totalSessions;

          return GestureDetector(
            onTap: () => setState(() => _selectedPackage = pkg),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _packageIcon(pkg.type),
                      color: typeColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                pkg.name,
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            if (pkg.discountPercent > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Hemat ${pkg.discountPercent}%',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _statChip(
                              Icons.repeat_rounded,
                              '${pkg.totalSessions}× /tahun',
                            ),
                            const SizedBox(width: 6),
                            _statChip(
                              Icons.calendar_today_rounded,
                              'tiap ${pkg.intervalMonths} bln',
                            ),
                          ],
                        ),
                        // ─── Estimasi harga ─────────────────
                        if (_minBasePrice > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                'Mulai ',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _fmt(estimasiPerTahun),
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                ' /thn',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (pkg.discountPercent > 0)
                            Text(
                              _fmt(normalPerTahun),
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                        // ────────────────────────────────────
                        if ((pkg.description ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            pkg.description!,
                            style: TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
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
      ],
    );
  }

  // ─── Step 2: Pilih Service ────────────────────────────────────

  Widget _buildStep2() {
    if (_loadingServices)
      return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (_bpName != null)
          _buildInfoBanner(
            icon: Icons.business_rounded,
            color: Colors.blue,
            text:
                'Layanan dari mitra: $_bpName. Pilih layanan yang ingin kamu langganan.',
          ),
        const SizedBox(height: 16),
        if (_services.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Layanan Tidak Tersedia',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Layanan cuci langganan belum tersedia di area kamu saat ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._services.map((service) {
            final isSelected = _selectedServices.containsKey(
              service.bpServiceId,
            );
            final item = _selectedServices[service.bpServiceId];
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selectedServices.remove(service.bpServiceId);
                      } else {
                        _selectedServices[service.bpServiceId] =
                            SubscriptionServiceItem(
                              bpServiceId: service.bpServiceId,
                              name: service.name,
                              basePrice: service.basePrice,
                              bannerUrl: service.bannerUrl,
                            );
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
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
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (isSelected) {
                          _selectedServices.remove(service.bpServiceId);
                        } else {
                          _selectedServices[service.bpServiceId] =
                              SubscriptionServiceItem(
                                bpServiceId: service.bpServiceId,
                                name: service.name,
                                basePrice: service.basePrice,
                              );
                        }
                      }),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_fmt(service.basePrice)} / sesi',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSelected && item != null)
                    _qtySelector(
                      qty: item.quantity,
                      onMinus: () => setState(() {
                        if (item.quantity > 1)
                          item.quantity--;
                        else
                          _selectedServices.remove(service.bpServiceId);
                      }),
                      onPlus: () => setState(() {
                        if (item.quantity < 10) item.quantity++;
                      }),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ─── Step 3: Atur Jadwal ──────────────────────────────────────

  Widget _buildStep3() {
    if (_scheduleDates.isEmpty)
      return const Center(child: Text('Memuat jadwal...'));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoBanner(
          icon: Icons.info_rounded,
          color: Colors.orange,
          text:
              'Atur jadwal untuk ${_selectedPackage!.totalSessions} sesi cuci AC kamu. '
              'Jadwal pertama bebas, sesi berikutnya sesuai interval paket.',
        ),
        const SizedBox(height: 20),
        ...List.generate(
          _selectedPackage!.totalSessions,
          (i) => _buildScheduleCard(i),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildScheduleCard(int index) {
    final date = _scheduleDates[index];
    final time = _scheduleTimes[index];

    DateTime? minDate;
    DateTime? maxDate;
    if (index > 0 && _scheduleDates[0] != null) {
      final base = _scheduleDates[0]!;
      final center = base.add(
        Duration(days: index * _selectedPackage!.intervalMonths * 30),
      );
      minDate = center.subtract(const Duration(days: 7));
      maxDate = center.add(const Duration(days: 7));
    } else {
      minDate = DateTime.now();
      maxDate = DateTime.now().add(const Duration(days: 365));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: date != null && time != null
              ? AppTheme.primary
              : Colors.grey.shade200,
          width: date != null && time != null ? 2 : 1,
        ),
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
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: date != null ? AppTheme.primary : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: date != null ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Sesi ke-${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (index > 0 && _selectedPackage != null) ...[
                const Spacer(),
                Text(
                  '±7 hari dari ${_selectedPackage!.intervalMonths} bln setelah sesi 1',
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
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
              if (picked != null)
                setState(() => _scheduleDates[index] = picked);
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
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    date != null
                        ? DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date)
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _timeSlots.map((slot) {
              final isSelected = time == slot;
              return GestureDetector(
                onTap: () => setState(() => _scheduleTimes[index] = slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
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
                      fontSize: 13,
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

  // ─── Step 4: Preview & Bayar ──────────────────────────────────

  Widget _buildStep4() {
    if (_loadingPreview)
      return const Center(child: CircularProgressIndicator());
    if (_preview == null)
      return const Center(child: Text('Gagal memuat preview.'));

    final grandTotal = _grandTotal;
    final cukupDikariPay = _dikariPayBalance >= grandTotal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // ─── Ringkasan langganan ─────────────────────────────
        Container(
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
              _sectionTitle('Ringkasan Langganan'),
              _previewRow('Paket', _selectedPackage!.name),
              _previewRow(
                'Frekuensi',
                '${_selectedPackage!.totalSessions}× cuci / tahun',
              ),
              ..._selectedServices.values.map(
                (s) => _previewRow(
                  '${s.name} ×${s.quantity}',
                  '${_fmt(s.subtotalPerSession)} / sesi',
                ),
              ),
              const Divider(height: 20),
              _previewRow('Subtotal (normal)', _fmt(_preview!.subtotal)),
              if (_preview!.discountAmount > 0)
                _previewRow(
                  'Diskon paket',
                  '- ${_fmt(_preview!.discountAmount)}',
                  valueColor: Colors.green.shade600,
                ),
              if (_discount > 0)
                _previewRow(
                  'Diskon kupon',
                  '- ${_fmt(_discount)}',
                  valueColor: Colors.green.shade600,
                ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Bayar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    _fmt(grandTotal),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ─── Kupon ───────────────────────────────────────────
        Container(
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
              Row(
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  _sectionTitle('Kode Promo'),
                ],
              ),
              const SizedBox(height: 12),
              if (_couponResult != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _couponResult!.couponName ?? '',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Hemat ${_fmt(_discount)}',
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _removeCoupon,
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _couponCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Masukkan kode promo',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppTheme.primary,
                              width: 2,
                            ),
                          ),
                          errorText: _couponError ? _couponErrorMsg : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _validatingCoupon ? null : _validateCoupon,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _validatingCoupon
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Pakai'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ─── DikariPay option ────────────────────────────────
        GestureDetector(
          onTap: cukupDikariPay
              ? () => setState(() {
                  _useDikariPay = !_useDikariPay;
                  _selectedChannel = null;
                })
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _useDikariPay ? AppTheme.primary : Colors.grey.shade200,
                width: _useDikariPay ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DikariPay',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Saldo: ${_fmt(_dikariPayBalance)}',
                        style: TextStyle(
                          color: cukupDikariPay
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!cukupDikariPay)
                        Text(
                          'Saldo tidak mencukupi',
                          style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!cukupDikariPay)
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/dikaripay'),
                    child: const Text('Topup'),
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _useDikariPay
                          ? AppTheme.primary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _useDikariPay
                            ? AppTheme.primary
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: _useDikariPay
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
        ),
        const SizedBox(height: 20),

        // ─── Tripay channels ─────────────────────────────────
        _sectionTitle('Atau Bayar dengan'),
        ..._groupedChannels.entries.map(
          (entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: entry.value.asMap().entries.map((e) {
                    final idx = e.key;
                    final ch = e.value;
                    final isSelected =
                        !_useDikariPay && _selectedChannel?.code == ch.code;
                    return Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            _selectedChannel = ch;
                            _useDikariPay = false;
                          }),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ch.iconUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Image.network(
                                            ch.iconUrl!,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.payment_rounded,
                                                  size: 20,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.payment_rounded,
                                          size: 20,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ch.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (ch.feeFlat > 0 || ch.feePercent > 0)
                                        Text(
                                          ch.feeFlat > 0
                                              ? 'Biaya: ${_fmt(ch.feeFlat)}'
                                              : 'Biaya: ${ch.feePercent}%',
                                          style: TextStyle(
                                            color: AppTheme.onSurfaceVariant,
                                            fontSize: 11,
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
                        ),
                        if (idx < entry.value.length - 1)
                          Divider(
                            height: 1,
                            indent: 74,
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
      ],
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────

  Widget _buildBottomBar() {
    final labels = [
      'Pilih Paket',
      'Pilih Layanan',
      'Atur Jadwal',
      'Lihat Ringkasan',
      'Bayar Sekarang',
    ];

    final showTotal = _currentStep == 4 && _preview != null;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTotal) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Bayar',
                  style: TextStyle(color: AppTheme.onSurfaceVariant),
                ),
                Text(
                  _fmt(_grandTotal),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_submitting || _savingSchedule) ? null : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: (_submitting || _savingSchedule)
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      labels[_currentStep],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────

  Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
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
              style: TextStyle(color: color.withOpacity(0.9), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableCard({
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(child: child),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.grey.shade400,
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
  }

  Widget _qtySelector({
    required int qty,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      children: [
        GestureDetector(
          onTap: onMinus,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.remove_rounded,
              color: AppTheme.primary,
              size: 16,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '$qty',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        GestureDetector(
          onTap: onPlus,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _previewRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
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

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.onSurface,
      ),
    ),
  );

  Widget _emptyHint({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppTheme.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _primaryBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      'Utama',
      style: TextStyle(
        color: AppTheme.primary,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _statChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

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

  String _fmt(double amount) =>
      'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}';

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

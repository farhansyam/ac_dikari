import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/address_service.dart';
import '../services/phone_service.dart';
import '../services/order_service.dart';

enum OrderType { cuciReguler, pasangBaru, beliPasang, relokasi, perbaikan }

class OrderFlowScreen extends StatefulWidget {
  final OrderType orderType;
  const OrderFlowScreen({Key? key, this.orderType = OrderType.cuciReguler})
    : super(key: key);

  @override
  State<OrderFlowScreen> createState() => _OrderFlowScreenState();
}

class _OrderFlowScreenState extends State<OrderFlowScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  late OrderService _orderService;
  late AddressService _addressService;
  late PhoneService _phoneService;

  // Step 1
  PhoneModel? _selectedPhone;
  AddressModel? _selectedAddress;
  List<PhoneModel> _phones = [];
  List<AddressModel> _addresses = [];
  bool _loadingStep1 = true;

  // Relokasi
  String? _relocationType;
  AddressModel? _selectedOriginAddress;

  // Step 2 — non-perbaikan
  List<ServiceModel> _servicesJasa = [];
  List<ServiceModel> _servicesUnit = [];
  List<String> _timeSlots = [];
  Map<int, OrderItemInput> _selectedItems = {};
  bool _loadingStep2 = false;

  // Step 2 — perbaikan
  ServiceModel? _selectedSurveyService;
  bool _loadingPerbaikan = false;

  // Step 3 — Keluhan (perbaikan)
  List<String> _selectedKeluhan = [];
  final _keluhanLainnyaController = TextEditingController();
  bool _showKeluhanLainnya = false;

  static const _keluhanOptions = [
    'AC tidak dingin',
    'AC bocor',
    'AC berisik',
    'AC mati total',
    'AC terbakar',
  ];

  // Step 4
  DateTime? _selectedDate;
  String? _selectedTime;

  bool _submitting = false;

  static const double _apartmentSurcharge = 20000;

  // ─── Helpers ─────────────────────────────────────────────────

  bool get _isPerbaikan => widget.orderType == OrderType.perbaikan;
  bool get _isRelokasi => widget.orderType == OrderType.relokasi;
  bool get _isBeliPasang => widget.orderType == OrderType.beliPasang;
  bool get _isDiffLoc => _relocationType == 'different_location';

  int get _totalSteps => _isPerbaikan ? 4 : (_isRelokasi ? 4 : 3);

  String get _screenTitle {
    switch (widget.orderType) {
      case OrderType.pasangBaru:
        return 'Pasang Baru';
      case OrderType.beliPasang:
        return 'Beli + Pasang';
      case OrderType.relokasi:
        return 'Relokasi AC';
      case OrderType.perbaikan:
        return 'Service Perbaikan';
      default:
        return 'Cuci AC';
    }
  }

  String get _jasaCategory {
    switch (widget.orderType) {
      case OrderType.pasangBaru:
      case OrderType.beliPasang:
        return 'pasang_baru';
      case OrderType.relokasi:
        return _isDiffLoc ? 'relokasi_bongkar' : 'relokasi';
      default:
        return 'cuci_reguler';
    }
  }

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _orderService = OrderService(
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
    _loadStep1Data();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _keluhanLainnyaController.dispose();
    super.dispose();
  }

  // ─── Load Data ────────────────────────────────────────────────

  Future<void> _loadStep1Data() async {
    setState(() => _loadingStep1 = true);
    try {
      final results = await Future.wait([
        _phoneService.getPhones(),
        _addressService.getAddresses(),
      ]);
      if (!mounted) return;
      final phones = results[0] as List<PhoneModel>;
      final addresses = results[1] as List<AddressModel>;
      setState(() {
        _phones = phones;
        _addresses = addresses;
        _selectedPhone = phones.firstWhere(
          (p) => p.isPrimary,
          orElse: () => phones.first,
        );
        _selectedAddress = addresses.firstWhere(
          (a) => a.isPrimary,
          orElse: () => addresses.first,
        );
        _loadingStep1 = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStep1 = false);
    }
  }

  Future<void> _loadPerbaikanServices() async {
    if (_selectedSurveyService != null) return;
    setState(() => _loadingPerbaikan = true);
    try {
      final city = _selectedAddress?.cityName;
      final result = await _orderService.getServices(
        city: city,
        category: 'service_perbaikan_survey',
      );
      final services = result['services'] as List<ServiceModel>;
      final slots = result['time_slots'] as List<String>;
      if (!mounted) return;
      setState(() {
        _servicesJasa = services;
        _timeSlots = slots;
        if (services.length == 1) _selectedSurveyService = services.first;
        _loadingPerbaikan = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPerbaikan = false);
      _showSnackBar(e.toString());
    }
  }

  Future<void> _loadStep2Data() async {
    if (_servicesJasa.isNotEmpty) return;
    setState(() => _loadingStep2 = true);
    try {
      final city = _selectedAddress?.cityName;

      if (_isRelokasi && _isDiffLoc) {
        final results = await Future.wait([
          _orderService.getServices(city: city, category: 'relokasi_bongkar'),
          _orderService.getServices(city: city, category: 'relokasi_pasang'),
        ]);
        final bongkarServices = results[0]['services'] as List<ServiceModel>;
        final pasangServices = results[1]['services'] as List<ServiceModel>;
        final timeSlots = results[0]['time_slots'] as List<String>;

        if (!mounted) return;
        setState(() {
          _servicesJasa = [...bongkarServices, ...pasangServices];
          _timeSlots = timeSlots;
          _loadingStep2 = false;
        });
        _autoSelectRelokasiServices(bongkarServices, pasangServices);
      } else {
        final jasaResult = await _orderService.getServices(
          city: city,
          category: _jasaCategory,
        );
        List<ServiceModel> unitServices = [];
        if (_isBeliPasang) {
          final unitResult = await _orderService.getServices(
            city: city,
            category: 'unit',
          );
          unitServices = unitResult['services'] as List<ServiceModel>;
        }
        if (!mounted) return;
        setState(() {
          _servicesJasa = jasaResult['services'] as List<ServiceModel>;
          _servicesUnit = unitServices;
          _timeSlots = jasaResult['time_slots'] as List<String>;
          _loadingStep2 = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStep2 = false);
      _showSnackBar(e.toString());
    }
  }

  void _autoSelectRelokasiServices(
    List<ServiceModel> bongkar,
    List<ServiceModel> pasang,
  ) {
    setState(() {
      for (final s in bongkar) {
        _selectedItems[s.id] = OrderItemInput(
          bpServiceId: s.id,
          name: s.name,
          finalPrice: s.finalPrice,
        );
      }
      for (final s in pasang) {
        _selectedItems[s.id] = OrderItemInput(
          bpServiceId: s.id,
          name: s.name,
          finalPrice: s.finalPrice,
        );
      }
    });
  }

  // ─── Navigation ───────────────────────────────────────────────

  void _nextStep() {
    // Step 0 — Kontak & Alamat
    if (_currentStep == 0) {
      if (_selectedPhone == null || _selectedAddress == null) {
        _showSnackBar('Pilih nomor kontak dan alamat terlebih dahulu.');
        return;
      }
      if (_isPerbaikan) {
        _loadPerbaikanServices();
      } else if (!_isRelokasi) {
        _loadStep2Data();
      }
    }

    // Step 1 relokasi — pilih tipe
    if (_isRelokasi && _currentStep == 1) {
      if (_relocationType == null) {
        _showSnackBar('Pilih tipe relokasi terlebih dahulu.');
        return;
      }
      if (_isDiffLoc && _selectedOriginAddress == null) {
        _showSnackBar('Pilih alamat asal (lokasi bongkar).');
        return;
      }
      _loadStep2Data();
    }

    // Step 1 perbaikan — pilih layanan survey
    if (_isPerbaikan && _currentStep == 1) {
      if (_selectedSurveyService == null) {
        _showSnackBar('Pilih layanan survey terlebih dahulu.');
        return;
      }
    }

    // Step 2 perbaikan — keluhan
    if (_isPerbaikan && _currentStep == 2) {
      if (_selectedKeluhan.isEmpty && _keluhanLainnyaController.text.isEmpty) {
        _showSnackBar('Pilih minimal satu keluhan AC.');
        return;
      }
    }

    // Step layanan — non-perbaikan
    final serviceStep = _isRelokasi ? 2 : 1;
    if (!_isPerbaikan && _currentStep == serviceStep) {
      if (_selectedItems.isEmpty) {
        _showSnackBar('Pilih minimal satu layanan.');
        return;
      }
      if (_isBeliPasang) {
        final hasUnit = _selectedItems.values.any(
          (item) => _servicesUnit.any((s) => s.id == item.bpServiceId),
        );
        if (!hasUnit) {
          _showSnackBar('Pilih minimal satu unit AC.');
          return;
        }
      }
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _isPerbaikan ? _submitPerbaikanOrder() : _submitOrder();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  // ─── Submit biasa ─────────────────────────────────────────────

  Future<void> _submitOrder() async {
    if (_selectedDate == null || _selectedTime == null) {
      _showSnackBar('Pilih tanggal dan jam terlebih dahulu.');
      return;
    }
    setState(() => _submitting = true);

    final payload = <String, dynamic>{
      'user_phone_id': _selectedPhone!.id,
      'address_id': _selectedAddress!.id,
      'scheduled_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      'scheduled_time': _selectedTime,
      'notes': null,
      'items': _selectedItems.values
          .map(
            (item) => {
              'bp_service_id': item.bpServiceId,
              'quantity': item.quantity,
            },
          )
          .toList(),
    };

    if (_isRelokasi) {
      payload['order_type'] = 'relokasi';
      payload['relocation_type'] = _relocationType;
      if (_isDiffLoc && _selectedOriginAddress != null) {
        payload['origin_address_id'] = _selectedOriginAddress!.id;
      }
    }

    try {
      final order = await _orderService.createOrder(payload);
      if (!mounted) return;
      setState(() => _submitting = false);
      _showOrderSuccess(order);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackBar(e.toString());
    }
  }

  // ─── Submit perbaikan ─────────────────────────────────────────

  Future<void> _submitPerbaikanOrder() async {
    if (_selectedDate == null || _selectedTime == null) {
      _showSnackBar('Pilih tanggal dan jam terlebih dahulu.');
      return;
    }
    if (_selectedSurveyService == null) {
      _showSnackBar('Layanan survey tidak tersedia.');
      return;
    }
    setState(() => _submitting = true);

    try {
      final order = await _orderService.createPerbaikanOrder({
        'bp_service_id': _selectedSurveyService!.id,
        'address_id': _selectedAddress!.id,
        'user_phone_id': _selectedPhone!.id,
        'scheduled_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'scheduled_time': _selectedTime,
        'notes': null,
        'keluhan': _selectedKeluhan,
        'keluhan_lainnya': _keluhanLainnyaController.text.isEmpty
            ? null
            : _keluhanLainnyaController.text,
      });
      if (!mounted) return;
      setState(() => _submitting = false);
      _showPerbaikanSuccess(order);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackBar(e.toString());
    }
  }

  void _showOrderSuccess(OrderModel order) {
    final isDiffLocOrder = order.relocationType == 'different_location';
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
            Text(
              'Pesanan Berhasil!',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isDiffLocOrder
                  ? 'Pesanan #${order.id} menunggu konfirmasi biaya transportasi dari mitra kami.'
                  : 'Pesanan #${order.id} sedang menunggu konfirmasi dari mitra kami.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (!isDiffLocOrder) ...[
              const SizedBox(height: 8),
              Text(
                _formatCurrency(order.totalAmount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (!isDiffLocOrder) {
                  Navigator.pushReplacementNamed(
                    context,
                    '/payment',
                    arguments: order,
                  );
                } else {
                  Navigator.pushReplacementNamed(context, '/pesanan');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isDiffLocOrder ? 'Lihat Pesanan' : 'Lanjut ke Pembayaran',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPerbaikanSuccess(OrderModel order) {
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
                color: Colors.purple.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.build_circle_rounded,
                color: Colors.purple.shade500,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pesanan Perbaikan Berhasil!',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pesanan #${order.id} sedang menunggu konfirmasi mitra. '
              'Teknisi akan datang untuk melakukan survey AC Anda.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_rounded,
                    color: Colors.purple.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Biaya survey: ${_formatCurrency(order.totalAmount)}',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
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
                Navigator.pushReplacementNamed(
                  context,
                  '/payment',
                  arguments: order,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Lanjut ke Pembayaran'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatCurrency(double amount) =>
      'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}';

  double get _subtotal => _isPerbaikan
      ? (_selectedSurveyService?.finalPrice ?? 0)
      : _selectedItems.values.fold(0, (sum, item) => sum + item.subtotal);
  double get _surcharge =>
      _selectedAddress?.propertyType == 'apartemen' ? _apartmentSurcharge : 0;
  double get _total => _subtotal + _surcharge;

  // ─── Build ────────────────────────────────────────────────────

  List<Widget> get _pages {
    if (_isPerbaikan) {
      return [
        _buildStep1(), // Kontak & Alamat
        _buildStepPerbaikan(), // Pilih layanan survey
        _buildStepKeluhan(), // Keluhan AC
        _buildStep3(), // Jadwal
      ];
    }
    if (_isRelokasi) {
      return [
        _buildStep1(),
        _buildStepRelokasi(),
        _buildStep2(),
        _buildStep3(),
      ];
    }
    return [_buildStep1(), _buildStep2(), _buildStep3()];
  }

  List<String> get _stepLabels {
    if (_isPerbaikan) {
      return [
        'Lanjut ke Layanan',
        'Lanjut ke Keluhan',
        'Lanjut ke Jadwal',
        'Buat Pesanan',
      ];
    }
    if (_isRelokasi) {
      return [
        'Lanjut ke Tipe Relokasi',
        'Lanjut ke Layanan',
        'Lanjut ke Jadwal',
        'Buat Pesanan',
      ];
    }
    return ['Lanjut ke Layanan', 'Lanjut ke Jadwal', 'Buat Pesanan'];
  }

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
          onPressed: _prevStep,
        ),
        title: Column(
          children: [
            Text(
              _screenTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            _buildStepIndicator(),
          ],
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_totalSteps, (index) {
        final isActive = index == _currentStep;
        final isDone = index < _currentStep;
        return Row(
          children: [
            if (index > 0)
              Container(
                width: 14,
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
                        '${index + 1}',
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

  // ─── Step 1: Kontak & Alamat ──────────────────────────────────

  Widget _buildStep1() {
    if (_loadingStep1) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isRelokasi || _isPerbaikan) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _isPerbaikan ? Colors.purple.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isPerbaikan
                    ? Colors.purple.shade200
                    : Colors.blue.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isPerbaikan ? Icons.build_rounded : Icons.info_rounded,
                  color: _isPerbaikan
                      ? Colors.purple.shade700
                      : Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isPerbaikan
                        ? 'Pilih alamat lokasi AC yang ingin disurvei.'
                        : 'Pilih alamat tujuan pemasangan AC.',
                    style: TextStyle(
                      color: _isPerbaikan
                          ? Colors.purple.shade700
                          : Colors.blue.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        _buildSectionTitle('Nomor yang Bisa Dihubungi'),
        if (_phones.isEmpty)
          _buildEmptyHint(
            icon: Icons.phone_outlined,
            message: 'Belum ada nomor kontak.',
            actionLabel: 'Tambah Nomor',
            onTap: () => Navigator.pushNamed(
              context,
              '/kontak',
            ).then((_) => _loadStep1Data()),
          )
        else
          ..._phones.map(
            (phone) => _buildSelectableCard(
              isSelected: _selectedPhone?.id == phone.id,
              onTap: () => setState(() => _selectedPhone = phone),
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
                              phone.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (phone.isPrimary) ...[
                              const SizedBox(width: 6),
                              _primaryBadge(),
                            ],
                          ],
                        ),
                        Text(
                          phone.phoneNumber,
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
        const SizedBox(height: 24),
        _buildSectionTitle(
          _isRelokasi
              ? 'Alamat Tujuan (Pasang)'
              : _isPerbaikan
              ? 'Alamat Lokasi AC'
              : 'Alamat Pengerjaan',
        ),
        if (_addresses.isEmpty)
          _buildEmptyHint(
            icon: Icons.location_off_rounded,
            message: 'Belum ada alamat tersimpan.',
            actionLabel: 'Tambah Alamat',
            onTap: () => Navigator.pushNamed(
              context,
              '/alamat',
            ).then((_) => _loadStep1Data()),
          )
        else
          ..._addresses.map(
            (address) => _buildSelectableCard(
              isSelected: _selectedAddress?.id == address.id,
              onTap: () => setState(() => _selectedAddress = address),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.propertyIcon,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              address.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (address.isPrimary) ...[
                              const SizedBox(width: 6),
                              _primaryBadge(),
                            ],
                          ],
                        ),
                        Text(
                          address.formattedAddress,
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
      ],
    );
  }

  // ─── Step Relokasi ────────────────────────────────────────────

  Widget _buildStepRelokasi() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Tipe Relokasi'),
        Text(
          'Apakah AC dipindahkan dalam satu lokasi atau ke lokasi berbeda?',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _buildRelokasOption(
          title: '1 Lokasi',
          subtitle:
              'AC dipindahkan dalam lokasi yang sama\n(contoh: pindah ruangan)',
          icon: Icons.home_rounded,
          value: 'same_location',
        ),
        const SizedBox(height: 12),
        _buildRelokasOption(
          title: 'Beda Lokasi',
          subtitle:
              'AC dipindahkan ke alamat berbeda\n(ada biaya transportasi)',
          icon: Icons.swap_horiz_rounded,
          value: 'different_location',
        ),
        if (_isDiffLoc) ...[
          const SizedBox(height: 24),
          _buildSectionTitle('Alamat Asal (Lokasi Bongkar)'),
          Text(
            'Pilih alamat di mana AC saat ini berada.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (_addresses.isEmpty)
            _buildEmptyHint(
              icon: Icons.location_off_rounded,
              message: 'Belum ada alamat tersimpan.',
              actionLabel: 'Tambah Alamat',
              onTap: () => Navigator.pushNamed(
                context,
                '/alamat',
              ).then((_) => _loadStep1Data()),
            )
          else
            ..._addresses.map(
              (address) => _buildSelectableCard(
                isSelected: _selectedOriginAddress?.id == address.id,
                onTap: () => setState(() => _selectedOriginAddress = address),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.propertyIcon,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                address.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (address.isPrimary) ...[
                                const SizedBox(width: 6),
                                _primaryBadge(),
                              ],
                            ],
                          ),
                          Text(
                            address.formattedAddress,
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
        ],
      ],
    );
  }

  Widget _buildRelokasOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _relocationType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _relocationType = value;
        if (value == 'same_location') _selectedOriginAddress = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.05) : Colors.white,
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.primary : Colors.grey.shade500,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primary : AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4,
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

  // ─── Step Perbaikan: Pilih layanan survey ─────────────────────

  Widget _buildStepPerbaikan() {
    if (_loadingPerbaikan) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bagaimana alur Service Perbaikan?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '1. Bayar biaya survey\n'
                      '2. Teknisi datang & survey kondisi AC\n'
                      '3. Kamu pilih lanjut/tidak berdasarkan hasil survey\n'
                      '4. Jika lanjut, bayar biaya perbaikan/cuci',
                      style: TextStyle(
                        color: Colors.purple.shade600,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        _buildSectionTitle('Pilih Layanan Survey'),

        if (_servicesJasa.isEmpty)
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
                  Text(
                    'Layanan Tidak Tersedia',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Maaf, layanan belum tersedia di kota ${_selectedAddress?.cityName ?? 'Anda'}.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._servicesJasa.map((service) {
            final isSelected = _selectedSurveyService?.id == service.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedSurveyService = service),
              child: AnimatedContainer(
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
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
                    const SizedBox(width: 12),
                    Expanded(
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
                          if (service.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              service.description,
                              style: TextStyle(
                                color: AppTheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            _formatCurrency(service.finalPrice),
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ─── Step Keluhan AC ──────────────────────────────────────────

  Widget _buildStepKeluhan() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ceritakan keluhan AC kamu agar teknisi bisa mempersiapkan diri sebelum datang.',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        _buildSectionTitle('Apa yang bermasalah dengan AC kamu?'),
        Text(
          'Pilih satu atau lebih keluhan.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Checklist keluhan
        ..._keluhanOptions.map((keluhan) {
          final selected = _selectedKeluhan.contains(keluhan);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) {
                _selectedKeluhan.remove(keluhan);
              } else {
                _selectedKeluhan.add(keluhan);
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primary.withOpacity(0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppTheme.primary : Colors.grey.shade200,
                  width: selected ? 2 : 1,
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    keluhan,
                    style: TextStyle(
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: selected ? AppTheme.primary : AppTheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Keluhan lainnya toggle
        GestureDetector(
          onTap: () => setState(() {
            _showKeluhanLainnya = !_showKeluhanLainnya;
            if (!_showKeluhanLainnya) {
              _keluhanLainnyaController.clear();
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _showKeluhanLainnya ? Colors.orange.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showKeluhanLainnya
                    ? Colors.orange.shade400
                    : Colors.grey.shade200,
                width: _showKeluhanLainnya ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _showKeluhanLainnya
                        ? Colors.orange.shade400
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _showKeluhanLainnya
                          ? Colors.orange.shade400
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: _showKeluhanLainnya
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  'Keluhan lainnya...',
                  style: TextStyle(
                    fontWeight: _showKeluhanLainnya
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: _showKeluhanLainnya
                        ? Colors.orange.shade700
                        : AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Text field keluhan lainnya
        if (_showKeluhanLainnya) ...[
          TextField(
            controller: _keluhanLainnyaController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ceritakan keluhan AC kamu...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // ─── Step 2: Layanan (non-perbaikan) ─────────────────────────

  Widget _buildStep2() {
    if (_loadingStep2) return const Center(child: CircularProgressIndicator());
    final allEmpty = _servicesJasa.isEmpty && _servicesUnit.isEmpty;
    if (allEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Layanan Tidak Tersedia',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Maaf, layanan belum tersedia di kota ${_selectedAddress?.cityName ?? 'Anda'}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bongkarServices = _isRelokasi && _isDiffLoc
        ? _servicesJasa.where((s) => s.category == 'relokasi_bongkar').toList()
        : <ServiceModel>[];
    final pasangServices = _isRelokasi && _isDiffLoc
        ? _servicesJasa.where((s) => s.category == 'relokasi_pasang').toList()
        : <ServiceModel>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        if (_isRelokasi && _isDiffLoc) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: Colors.blue.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Layanan relokasi bongkar dan pasang sudah otomatis dipilih.',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (bongkarServices.isNotEmpty) ...[
            _buildSectionTitle('Layanan Bongkar'),
            ...bongkarServices.map((s) => _buildServiceCard(s, readOnly: true)),
            const SizedBox(height: 20),
          ],
          if (pasangServices.isNotEmpty) ...[
            _buildSectionTitle('Layanan Pasang'),
            ...pasangServices.map((s) => _buildServiceCard(s, readOnly: true)),
          ],
        ] else if (_isBeliPasang && _servicesUnit.isNotEmpty) ...[
          _buildSectionTitle('Pilih Unit AC'),
          ..._servicesUnit.map(
            (s) => _buildServiceCard(s, isUnitSection: true),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Biaya Pemasangan'),
          ..._servicesJasa.map((s) => _buildServiceCard(s)),
        ] else ...[
          _buildSectionTitle(
            _isBeliPasang ? 'Biaya Pemasangan' : 'Pilih Layanan',
          ),
          if (!_isBeliPasang)
            Text(
              'Pilih layanan dan atur jumlah unit AC.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
          const SizedBox(height: 12),
          ..._servicesJasa.map((s) => _buildServiceCard(s)),
        ],
      ],
    );
  }

  Widget _buildServiceCard(
    ServiceModel service, {
    bool isUnitSection = false,
    bool readOnly = false,
  }) {
    final isSelected = _selectedItems.containsKey(service.id);
    final item = _selectedItems[service.id];

    return GestureDetector(
      onTap: readOnly
          ? null
          : () => setState(() {
              if (isSelected)
                _selectedItems.remove(service.id);
              else
                _selectedItems[service.id] = OrderItemInput(
                  bpServiceId: service.id,
                  name: service.name,
                  finalPrice: service.finalPrice,
                );
            }),
      child: AnimatedContainer(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (service.banner != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  '${AuthService.baseUrl.replaceAll('/api', '')}/storage/${service.banner}',
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (readOnly)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
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
                const SizedBox(width: 12),
                Expanded(
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
                      if (service.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          service.description,
                          style: TextStyle(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (service.discount > 0) ...[
                            Text(
                              _formatCurrency(service.basePrice),
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            isUnitSection
                                ? _formatCurrency(service.finalPrice)
                                : '${_formatCurrency(service.finalPrice)} / AC',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSelected && item != null && !readOnly)
                  _buildQtySelector(item, service.id),
                if (isSelected && item != null && readOnly)
                  _buildQtySelectorReadOnly(item, service.id),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtySelector(OrderItemInput item, int serviceId) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            if (item.quantity > 1)
              item.quantity--;
            else
              _selectedItems.remove(serviceId);
          }),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.remove_rounded,
              color: AppTheme.primary,
              size: 18,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${item.quantity}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() {
            if (item.quantity < 20) item.quantity++;
          }),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildQtySelectorReadOnly(OrderItemInput item, int serviceId) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            if (item.quantity > 1) item.quantity--;
          }),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.remove_rounded,
              color: AppTheme.primary,
              size: 18,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${item.quantity}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() {
            if (item.quantity < 20) item.quantity++;
          }),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  // ─── Step 3: Jadwal ───────────────────────────────────────────

  Widget _buildStep3() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ringkasan keluhan (hanya untuk perbaikan)
        if (_isPerbaikan &&
            (_selectedKeluhan.isNotEmpty ||
                _keluhanLainnyaController.text.isNotEmpty)) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
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
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Keluhan AC',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ..._selectedKeluhan.map(
                      (k) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          k,
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    if (_keluhanLainnyaController.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Lainnya: ${_keluhanLainnyaController.text}',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],

        _buildSectionTitle('Pilih Tanggal'),
        _buildDatePicker(),
        const SizedBox(height: 24),
        _buildSectionTitle('Pilih Jam'),
        _buildTimePicker(),
        const SizedBox(height: 24),
        _buildOrderSummary(),
      ],
    );
  }

  Widget _buildDatePicker() {
    final now = DateTime.now();
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? now,
          firstDate: now,
          lastDate: now.add(const Duration(days: 30)),
          locale: const Locale('id', 'ID'),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(primary: AppTheme.primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedDate != null
                ? AppTheme.primary
                : Colors.grey.shade200,
            width: _selectedDate != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              _selectedDate != null
                  ? DateFormat(
                      'EEEE, d MMMM yyyy',
                      'id_ID',
                    ).format(_selectedDate!)
                  : 'Pilih tanggal',
              style: TextStyle(
                color: _selectedDate != null
                    ? AppTheme.onSurface
                    : Colors.grey.shade400,
                fontWeight: _selectedDate != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _timeSlots.map((slot) {
        final isSelected = _selectedTime == slot;
        return GestureDetector(
          onTap: () => setState(() => _selectedTime = slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.grey.shade200,
              ),
            ),
            child: Text(
              slot,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Pesanan',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_isPerbaikan && _selectedSurveyService != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedSurveyService!.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  _formatCurrency(_selectedSurveyService!.finalPrice),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ] else ...[
            ..._selectedItems.values.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.name} x${item.quantity}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      _formatCurrency(item.subtotal),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_surcharge > 0) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Biaya Apartemen',
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatCurrency(_surcharge),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],

          if (_isRelokasi && _isDiffLoc) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      size: 14,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Biaya Transportasi',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Ditentukan mitra',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                _isRelokasi && _isDiffLoc
                    ? '${_formatCurrency(_total)} + transport'
                    : _formatCurrency(_total),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────

  Widget _buildBottomBar() {
    final serviceStep = _isRelokasi ? 2 : 1;
    final showTotal = _isPerbaikan
        ? _currentStep >= 1 && _selectedSurveyService != null
        : _currentStep >= serviceStep && _selectedItems.isNotEmpty;

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
          if (showTotal)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _formatCurrency(_total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _stepLabels[_currentStep],
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

  // ─── Widget helpers ───────────────────────────────────────────

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.onSurface,
      ),
    ),
  );

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

  Widget _buildEmptyHint({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 28),
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
}

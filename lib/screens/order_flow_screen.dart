import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/address_service.dart';
import '../services/phone_service.dart';
import '../services/order_service.dart';

class OrderFlowScreen extends StatefulWidget {
  const OrderFlowScreen({Key? key}) : super(key: key);

  @override
  State<OrderFlowScreen> createState() => _OrderFlowScreenState();
}

class _OrderFlowScreenState extends State<OrderFlowScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  late OrderService _orderService;
  late AddressService _addressService;
  late PhoneService _phoneService;

  // Step 1 — Kontak & Alamat
  PhoneModel? _selectedPhone;
  AddressModel? _selectedAddress;
  List<PhoneModel> _phones = [];
  List<AddressModel> _addresses = [];
  bool _loadingStep1 = true;

  // Step 2 — Pilih Layanan
  List<ServiceModel> _services = [];
  List<String> _timeSlots = [];
  Map<int, OrderItemInput> _selectedItems = {};
  bool _loadingStep2 = false;

  // Step 3 — Jadwal
  DateTime? _selectedDate;
  String? _selectedTime;

  // Submitting
  bool _submitting = false;

  static const double _apartmentSurcharge = 20000;

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
        // Auto-select primary
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStep1 = false);
    }
  }

  Future<void> _loadStep2Data() async {
    if (_services.isNotEmpty) return;
    setState(() => _loadingStep2 = true);
    try {
      final city = _selectedAddress?.cityName;
      final result = await _orderService.getServices(city: city);
      if (!mounted) return;
      setState(() {
        _services = result['services'] as List<ServiceModel>;
        _timeSlots = result['time_slots'] as List<String>;
        _loadingStep2 = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStep2 = false);
      _showSnackBar(e.toString());
    }
  }

  // ─── Navigation ───────────────────────────────────────────────

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedPhone == null || _selectedAddress == null) {
        _showSnackBar('Pilih nomor kontak dan alamat terlebih dahulu.');
        return;
      }
      _loadStep2Data();
    }

    if (_currentStep == 1) {
      if (_selectedItems.isEmpty) {
        _showSnackBar('Pilih minimal satu layanan.');
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitOrder();
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

  // ─── Submit ───────────────────────────────────────────────────

  Future<void> _submitOrder() async {
    if (_selectedDate == null || _selectedTime == null) {
      _showSnackBar('Pilih tanggal dan jam terlebih dahulu.');
      return;
    }

    setState(() => _submitting = true);

    final payload = {
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

  void _showOrderSuccess(OrderModel order) {
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
              'Pesanan #${order.id} sedang menunggu konfirmasi dari mitra kami.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(order.totalAmount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
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

  // ─── Helpers ──────────────────────────────────────────────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatCurrency(double amount) {
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}';
  }

  double get _subtotal =>
      _selectedItems.values.fold(0, (sum, item) => sum + item.subtotal);

  double get _surcharge =>
      _selectedAddress?.propertyType == 'apartemen' ? _apartmentSurcharge : 0;

  double get _total => _subtotal + _surcharge;

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
          onPressed: _prevStep,
        ),
        title: _buildStepIndicator(),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildStep1(), _buildStep2(), _buildStep3()],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Kontak & Alamat', 'Layanan', 'Jadwal'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep;
        final isDone = index < _currentStep;
        return Row(
          children: [
            if (index > 0)
              Container(
                width: 20,
                height: 2,
                color: isDone ? AppTheme.primary : Colors.grey.shade300,
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppTheme.primary
                        : isActive
                        ? AppTheme.primary
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  // ─── Step 1: Kontak & Alamat ──────────────────────────────────

  Widget _buildStep1() {
    if (_loadingStep1) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        _buildSectionTitle('Alamat Pengiriman'),
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
                        if (address.propertyType == 'apartemen') ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              '+ ${_formatCurrency(_apartmentSurcharge)} (apartemen)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
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
          ),
      ],
    );
  }

  // ─── Step 2: Pilih Layanan ────────────────────────────────────

  Widget _buildStep2() {
    if (_loadingStep2) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_services.isEmpty) {
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _buildSectionTitle('Pilih Layanan'),
        Text(
          'Pilih layanan yang dibutuhkan dan atur jumlah unit AC.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        ..._services.map((service) => _buildServiceCard(service)),
      ],
    );
  }

  Widget _buildServiceCard(ServiceModel service) {
    final isSelected = _selectedItems.containsKey(service.id);
    final item = _selectedItems[service.id];

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedItems.remove(service.id);
          } else {
            _selectedItems[service.id] = OrderItemInput(
              bpServiceId: service.id,
              name: service.name,
              finalPrice: service.finalPrice,
            );
          }
        });
      },
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
            // Banner image
            if (service.banner != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  'https://noegenetic-jiggly-lulu.ngrok-free.dev/storage/${service.banner}',
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  loadingBuilder: (_, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 120,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                // Checkbox
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

                // Info
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
                            '${_formatCurrency(service.finalPrice)} / AC',
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

                // Quantity selector
                if (isSelected && item != null)
                  _buildQtySelector(item, service.id),
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
          onTap: () {
            setState(() {
              if (item.quantity > 1) {
                item.quantity--;
              } else {
                _selectedItems.remove(serviceId);
              }
            });
          },
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
          onTap: () {
            setState(() {
              if (item.quantity < 20) item.quantity++;
            });
          },
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
        _buildSectionTitle('Pilih Tanggal'),
        _buildDatePicker(),
        const SizedBox(height: 24),
        _buildSectionTitle('Pilih Jam'),
        _buildTimePicker(),
        const SizedBox(height: 24),

        // Ringkasan order
        _buildOrderSummary(),
      ],
    );
  }

  Widget _buildDatePicker() {
    final now = DateTime.now();
    final firstDate = now.add(const Duration(days: 0));
    final lastDate = now.add(const Duration(days: 30));

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? firstDate,
          firstDate: firstDate,
          lastDate: lastDate,
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
            Icon(
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
                _formatCurrency(_total),
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
    final stepLabels = [
      'Lanjut ke Layanan',
      'Lanjut ke Jadwal',
      'Buat Pesanan',
    ];
    final label = stepLabels[_currentStep];

    // Tampilkan total di step 2 & 3
    final showTotal = _currentStep >= 1 && _selectedItems.isNotEmpty;

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
                      label,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.onSurface,
        ),
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

  Widget _primaryBadge() {
    return Container(
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
}

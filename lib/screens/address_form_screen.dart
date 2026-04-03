import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // ← tambah hide Path
import '../core/theme.dart';
import '../services/address_service.dart';

class AddressFormScreen extends StatefulWidget {
  final AddressService addressService;
  final AddressModel? existingAddress;

  const AddressFormScreen({
    Key? key,
    required this.addressService,
    this.existingAddress,
  }) : super(key: key);

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapController = MapController();

  final _labelCtrl = TextEditingController();
  final _fullAddressCtrl = TextEditingController();

  String _propertyType = 'rumah';
  bool _isPrimary = false;
  bool _saving = false;
  bool _loadingGps = false;

  List<WilayahItem> _provinces = [];
  List<WilayahItem> _cities = [];
  List<WilayahItem> _districts = [];
  List<WilayahItem> _villages = [];

  WilayahItem? _selectedProvince;
  WilayahItem? _selectedCity;
  WilayahItem? _selectedDistrict;
  WilayahItem? _selectedVillage;

  bool _loadingProvince = false;
  bool _loadingCity = false;
  bool _loadingDistrict = false;
  bool _loadingVillage = false;

  double? _latitude;
  double? _longitude;

  static const LatLng _defaultCenter = LatLng(-2.5489, 118.0149);
  static const double _defaultZoom = 5.0;
  static const double _pinZoom = 16.0;

  bool get _isEdit => widget.existingAddress != null;
  LatLng? get _markerPos =>
      _latitude != null ? LatLng(_latitude!, _longitude!) : null;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    if (_isEdit) _prefillForm();
  }

  void _prefillForm() {
    final addr = widget.existingAddress!;
    _labelCtrl.text = addr.label;
    _fullAddressCtrl.text = addr.fullAddress;
    _propertyType = addr.propertyType;
    _isPrimary = addr.isPrimary;
    _latitude = addr.latitude;
    _longitude = addr.longitude;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _fullAddressCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ─── Load Wilayah ─────────────────────────────────────────────

  Future<void> _loadProvinces() async {
    setState(() => _loadingProvince = true);
    try {
      final data = await widget.addressService.getProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = data;
        _loadingProvince = false;
      });
      if (_isEdit) {
        final addr = widget.existingAddress!;
        final found = _provinces.where((p) => p.id == addr.provinceId).toList();
        if (found.isNotEmpty) {
          setState(() => _selectedProvince = found.first);
          await _loadCities(
            addr.provinceId,
            prefillCityId: addr.cityId,
            prefillDistrictId: addr.districtId,
            prefillVillageId: addr.villageId,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProvince = false);
    }
  }

  Future<void> _loadCities(
    String provinceId, {
    String? prefillCityId,
    String? prefillDistrictId,
    String? prefillVillageId,
  }) async {
    setState(() {
      _loadingCity = true;
      _cities = [];
      _districts = [];
      _villages = [];
      _selectedCity = null;
      _selectedDistrict = null;
      _selectedVillage = null;
    });
    try {
      final data = await widget.addressService.getCities(provinceId);
      if (!mounted) return;
      setState(() {
        _cities = data;
        _loadingCity = false;
      });
      if (prefillCityId != null) {
        final found = _cities.where((c) => c.id == prefillCityId).toList();
        if (found.isNotEmpty) {
          setState(() => _selectedCity = found.first);
          await _loadDistricts(
            prefillCityId,
            prefillDistrictId: prefillDistrictId,
            prefillVillageId: prefillVillageId,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCity = false);
    }
  }

  Future<void> _loadDistricts(
    String cityId, {
    String? prefillDistrictId,
    String? prefillVillageId,
  }) async {
    setState(() {
      _loadingDistrict = true;
      _districts = [];
      _villages = [];
      _selectedDistrict = null;
      _selectedVillage = null;
    });
    try {
      final data = await widget.addressService.getDistricts(cityId);
      if (!mounted) return;
      setState(() {
        _districts = data;
        _loadingDistrict = false;
      });
      if (prefillDistrictId != null) {
        final found = _districts
            .where((d) => d.id == prefillDistrictId)
            .toList();
        if (found.isNotEmpty) {
          setState(() => _selectedDistrict = found.first);
          await _loadVillages(
            prefillDistrictId,
            prefillVillageId: prefillVillageId,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDistrict = false);
    }
  }

  Future<void> _loadVillages(
    String districtId, {
    String? prefillVillageId,
  }) async {
    setState(() {
      _loadingVillage = true;
      _villages = [];
      _selectedVillage = null;
    });
    try {
      final data = await widget.addressService.getVillages(districtId);
      if (!mounted) return;
      setState(() {
        _villages = data;
        _loadingVillage = false;
      });
      if (prefillVillageId != null) {
        final found = _villages.where((v) => v.id == prefillVillageId).toList();
        if (found.isNotEmpty) setState(() => _selectedVillage = found.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingVillage = false);
    }
  }

  // ─── GPS ──────────────────────────────────────────────────────

  Future<void> _getGpsLocation() async {
    setState(() => _loadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('GPS tidak aktif.');
        if (!mounted) return;
        setState(() => _loadingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Izin lokasi ditolak.');
          if (!mounted) return;
          setState(() => _loadingGps = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _loadingGps = false;
      });

      _mapController.move(LatLng(_latitude!, _longitude!), _pinZoom);
      _showSnackBar('Lokasi GPS berhasil diambil ✓');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingGps = false);
      _showSnackBar('Gagal mendapat lokasi GPS.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ─── Submit ───────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null ||
        _selectedCity == null ||
        _selectedDistrict == null) {
      _showSnackBar('Lengkapi data wilayah terlebih dahulu.');
      return;
    }

    setState(() => _saving = true);

    final payload = {
      'property_type': _propertyType,
      'label': _labelCtrl.text.trim(),
      'province_id': _selectedProvince!.id,
      'province_name': _selectedProvince!.name,
      'city_id': _selectedCity!.id,
      'city_name': _selectedCity!.name,
      'district_id': _selectedDistrict!.id,
      'district_name': _selectedDistrict!.name,
      'village_id': _selectedVillage?.id,
      'village_name': _selectedVillage?.name,
      'full_address': _fullAddressCtrl.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
      'is_primary': _isPrimary,
    };

    try {
      if (_isEdit) {
        await widget.addressService.updateAddress(
          widget.existingAddress!.id,
          payload,
        );
      } else {
        await widget.addressService.createAddress(payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnackBar(e.toString());
    }
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Alamat' : 'Tambah Alamat'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('Jenis Properti'),
            _buildPropertyTypeSelector(),
            const SizedBox(height: 20),

            _buildSectionTitle('Nama Alamat'),
            _buildTextField(
              controller: _labelCtrl,
              hint: 'Contoh: Rumah Utama, Kantor Jakarta',
              icon: Icons.label_rounded,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Nama alamat wajib diisi.' : null,
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('Wilayah'),
            _buildWilayahDropdown(
              label: 'Provinsi',
              items: _provinces,
              selected: _selectedProvince,
              loading: _loadingProvince,
              onChanged: (item) {
                setState(() => _selectedProvince = item);
                if (item != null) _loadCities(item.id);
              },
            ),
            const SizedBox(height: 12),
            _buildWilayahDropdown(
              label: 'Kota / Kabupaten',
              items: _cities,
              selected: _selectedCity,
              loading: _loadingCity,
              enabled: _selectedProvince != null,
              onChanged: (item) {
                setState(() => _selectedCity = item);
                if (item != null) _loadDistricts(item.id);
              },
            ),
            const SizedBox(height: 12),
            _buildWilayahDropdown(
              label: 'Kecamatan',
              items: _districts,
              selected: _selectedDistrict,
              loading: _loadingDistrict,
              enabled: _selectedCity != null,
              onChanged: (item) {
                setState(() => _selectedDistrict = item);
                if (item != null) _loadVillages(item.id);
              },
            ),
            const SizedBox(height: 12),
            _buildWilayahDropdown(
              label: 'Kelurahan / Desa (opsional)',
              items: _villages,
              selected: _selectedVillage,
              loading: _loadingVillage,
              enabled: _selectedDistrict != null,
              required: false,
              onChanged: (item) => setState(() => _selectedVillage = item),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('Alamat Lengkap'),
            _buildTextField(
              controller: _fullAddressCtrl,
              hint: 'Nama jalan, nomor rumah, RT/RW, patokan, dll.',
              icon: Icons.home_rounded,
              maxLines: 3,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Alamat lengkap wajib diisi.' : null,
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('Lokasi di Peta'),
            _buildMapSection(),
            const SizedBox(height: 20),

            _buildPrimarySwitch(),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                    : Text(
                        _isEdit ? 'Simpan Perubahan' : 'Simpan Alamat',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Map Section ──────────────────────────────────────────────

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_markerPos != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.my_location_rounded,
                  size: 16,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Peta
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 280,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _markerPos ?? _defaultCenter,
                    initialZoom: _markerPos != null ? _pinZoom : _defaultZoom,
                    onTap: (_, latLng) {
                      setState(() {
                        _latitude = latLng.latitude;
                        _longitude = latLng.longitude;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ac_dikari',
                    ),
                    if (_markerPos != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _markerPos!,
                            width: 48,
                            height: 56,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(
                                          0.4,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                CustomPaint(
                                  size: const Size(14, 8),
                                  painter: _TrianglePainter(AppTheme.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Tombol GPS + Zoom
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      _mapButton(
                        icon: _loadingGps
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary,
                                ),
                              )
                            : const Icon(
                                Icons.gps_fixed_rounded,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                        onTap: _loadingGps ? null : _getGpsLocation,
                      ),
                      const SizedBox(height: 8),
                      _mapButton(
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.black87,
                          size: 20,
                        ),
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _mapButton(
                        icon: const Icon(
                          Icons.remove_rounded,
                          color: Colors.black87,
                          size: 20,
                        ),
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        ),
                      ),
                    ],
                  ),
                ),

                // Hint
                if (_markerPos == null)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Tap peta atau gunakan tombol GPS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        Text(
          'Tap di peta untuk menaruh pin, atau gunakan tombol GPS untuk lokasi saat ini. (Opsional)',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.onSurfaceVariant,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _mapButton({required Widget icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: icon),
      ),
    );
  }

  // ─── Widget helpers ───────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPropertyTypeSelector() {
    final types = [
      {'value': 'rumah', 'label': 'Rumah', 'icon': '🏠'},
      {'value': 'kantor', 'label': 'Kantor', 'icon': '🏢'},
      {'value': 'apartemen', 'label': 'Apartemen', 'icon': '🏙️'},
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _propertyType == type['value'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _propertyType = type['value']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(type['icon']!, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(
                    type['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildWilayahDropdown({
    required String label,
    required List<WilayahItem> items,
    required WilayahItem? selected,
    required bool loading,
    required ValueChanged<WilayahItem?> onChanged,
    bool enabled = true,
    bool required = true,
  }) {
    return DropdownButtonFormField<WilayahItem>(
      value: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade50,
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
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      validator: required
          ? (v) => v == null ? '$label wajib dipilih.' : null
          : null,
      hint: Text(
        enabled ? 'Pilih $label' : 'Pilih wilayah sebelumnya',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: enabled && !loading ? onChanged : null,
    );
  }

  Widget _buildPrimarySwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jadikan Alamat Utama',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Alamat ini akan dipakai secara default saat memesan.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPrimary,
            onChanged: (v) => setState(() => _isPrimary = v),
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

// ─── Painter segitiga marker ──────────────────────────────────────
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => color != old.color;
}

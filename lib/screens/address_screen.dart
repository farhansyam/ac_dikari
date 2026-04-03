import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/address_service.dart';
import 'address_form_screen.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({Key? key}) : super(key: key);

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  late AddressService _addressService;
  List<AddressModel> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _addressService = AddressService(
      baseUrl: '${AuthService.baseUrl}',
      authService: auth,
    );
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final addresses = await _addressService.getAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
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

  Future<void> _setPrimary(AddressModel address) async {
    try {
      await _addressService.setPrimary(address.id);
      await _loadAddresses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Alamat?'),
        content: Text('Alamat "${address.label}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _addressService.deleteAddress(address.id);
      await _loadAddresses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat berhasil dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goToForm({AddressModel? address}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressFormScreen(
          addressService: _addressService,
          existingAddress: address,
        ),
      ),
    );
    if (result == true) await _loadAddresses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Kelola Alamat'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _addresses.isEmpty
          ? _buildEmpty()
          : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _goToForm(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Tambah Alamat',
          style: TextStyle(fontWeight: FontWeight.bold),
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
              'Gagal memuat alamat',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAddresses,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
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
                Icons.location_off_rounded,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Alamat',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan alamat pengiriman\nuntuk memesan layanan.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadAddresses,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _addresses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _buildAddressCard(_addresses[index]),
      ),
    );
  }

  Widget _buildAddressCard(AddressModel address) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: address.isPrimary
            ? Border.all(color: AppTheme.primary, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  address.propertyIcon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address.label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (address.isPrimary) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Utama',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        address.propertyType[0].toUpperCase() +
                            address.propertyType.substring(1),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _goToForm(address: address);
                    if (value == 'primary') _setPrimary(address);
                    if (value == 'delete') _deleteAddress(address);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    if (!address.isPrimary)
                      const PopupMenuItem(
                        value: 'primary',
                        child: Row(
                          children: [
                            Icon(Icons.star_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Jadikan Utama'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_rounded,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 12),

            // Alamat
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address.formattedAddress,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),

            // Koordinat GPS
            if (address.latitude != null && address.longitude != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 14,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${address.latitude!.toStringAsFixed(6)}, ${address.longitude!.toStringAsFixed(6)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.green.shade600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

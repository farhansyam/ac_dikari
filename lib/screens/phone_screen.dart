import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/phone_service.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({Key? key}) : super(key: key);

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  late PhoneService _phoneService;
  List<PhoneModel> _phones = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _phoneService = PhoneService(
      baseUrl: AuthService.baseUrl,
      authService: auth,
    );
    _loadPhones();
  }

  Future<void> _loadPhones() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final phones = await _phoneService.getPhones();
      if (!mounted) return;
      setState(() {
        _phones = phones;
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

  Future<void> _setPrimary(PhoneModel phone) async {
    try {
      await _phoneService.setPrimary(phone.id);
      await _loadPhones();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    }
  }

  Future<void> _deletePhone(PhoneModel phone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Nomor?'),
        content: Text(
          'Nomor "${phone.label} - ${phone.phoneNumber}" akan dihapus.',
        ),
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
      await _phoneService.deletePhone(phone.id);
      await _loadPhones();
      if (!mounted) return;
      _showSnackBar('Nomor berhasil dihapus.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showForm({PhoneModel? phone}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PhoneFormSheet(phoneService: _phoneService, existingPhone: phone),
    );
    if (result == true) await _loadPhones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Nomor Kontak'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _phones.isEmpty
          ? _buildEmpty()
          : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Tambah Nomor',
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
              'Gagal memuat nomor',
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
              onPressed: _loadPhones,
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
                Icons.phone_outlined,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Nomor',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan nomor kontak yang bisa\ndihubungi saat order layanan.',
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
      onRefresh: _loadPhones,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _phones.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _buildPhoneCard(_phones[index]),
      ),
    );
  }

  Widget _buildPhoneCard(PhoneModel phone) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: phone.isPrimary
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
                Icons.phone_rounded,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        phone.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (phone.isPrimary) ...[
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
                  const SizedBox(height: 2),
                  Text(
                    phone.phoneNumber,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _showForm(phone: phone);
                if (value == 'primary') _setPrimary(phone);
                if (value == 'copy') {
                  Clipboard.setData(ClipboardData(text: phone.phoneNumber));
                  _showSnackBar('Nomor disalin ke clipboard.');
                }
                if (value == 'delete') _deletePhone(phone);
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
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Salin Nomor'),
                    ],
                  ),
                ),
                if (!phone.isPrimary)
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
                      Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Hapus', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Sheet Form ────────────────────────────────────────────

class _PhoneFormSheet extends StatefulWidget {
  final PhoneService phoneService;
  final PhoneModel? existingPhone;

  const _PhoneFormSheet({required this.phoneService, this.existingPhone});

  @override
  State<_PhoneFormSheet> createState() => _PhoneFormSheetState();
}

class _PhoneFormSheetState extends State<_PhoneFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isPrimary = false;
  bool _saving = false;

  final List<String> _labelSuggestions = [
    'HP Utama',
    'WhatsApp',
    'Kantor',
    'Rumah',
    'HP Alternatif',
  ];

  bool get _isEdit => widget.existingPhone != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _labelCtrl.text = widget.existingPhone!.label;
      _phoneCtrl.text = widget.existingPhone!.phoneNumber;
      _isPrimary = widget.existingPhone!.isPrimary;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// Validasi nomor HP — return pesan error atau null jika valid
  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Nomor telepon wajib diisi.';
    }

    final trimmed = v.trim();

    // Harus diawali 0 atau + (format Indonesia: 08xx atau +628xx)
    if (!trimmed.startsWith('0') && !trimmed.startsWith('+')) {
      return 'Nomor harus diawali 0 (misal 0812) atau +62.';
    }

    // Hitung digit saja — strip semua karakter non-digit
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length < 10) {
      return 'Nomor minimal 10 digit (misal: 0812-3456-7890).';
    }

    if (digitsOnly.length > 15) {
      return 'Nomor terlalu panjang (maksimal 15 digit).';
    }

    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final payload = {
      'label': _labelCtrl.text.trim(),
      'phone_number': _phoneCtrl.text.trim(),
      'is_primary': _isPrimary,
    };

    try {
      if (_isEdit) {
        await widget.phoneService.updatePhone(
          widget.existingPhone!.id,
          payload,
        );
      } else {
        await widget.phoneService.createPhone(payload);
      }
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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
                  _isEdit ? 'Edit Nomor' : 'Tambah Nomor',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // ─── Label ────────────────────────────────
                Text(
                  'Label',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _labelCtrl,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Label wajib diisi.'
                      : null,
                  decoration: _inputDecoration(
                    hint: 'Contoh: HP Utama, WhatsApp',
                    icon: Icons.label_rounded,
                  ),
                ),
                const SizedBox(height: 8),

                // Label suggestions
                Wrap(
                  spacing: 8,
                  children: _labelSuggestions.map((label) {
                    return GestureDetector(
                      onTap: () => setState(() => _labelCtrl.text = label),
                      child: Chip(
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: AppTheme.primary.withOpacity(0.08),
                        side: BorderSide(
                          color: AppTheme.primary.withOpacity(0.2),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ─── Nomor telepon ────────────────────────
                Text(
                  'Nomor Telepon',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Format: 08xx-xxxx-xxxx atau +628xx-xxxx-xxxx',
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  // Hanya angka, +, -, dan spasi — huruf diblokir
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                  ],
                  validator: _validatePhone,
                  decoration: _inputDecoration(
                    hint: '08xx xxxx xxxx',
                    icon: Icons.phone_rounded,
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Jadikan utama ────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Jadikan Nomor Utama',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch(
                        value: _isPrimary,
                        onChanged: (v) => setState(() => _isPrimary = v),
                        activeColor: AppTheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Tombol simpan ────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
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
                        : Text(
                            _isEdit ? 'Simpan Perubahan' : 'Simpan Nomor',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

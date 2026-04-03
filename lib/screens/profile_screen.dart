import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F9FC),
          body: auth.isLoggedIn
              ? _buildLoggedIn(context, auth)
              : _buildGuest(context),
        );
      },
    );
  }

  // ─── Tampilan Guest (belum login) ────────────────────────────
  Widget _buildGuest(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
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
                  Icons.person_outline_rounded,
                  size: 52,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Belum Masuk',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masuk untuk mengakses profil,\nriwayat pesanan, dan fitur lainnya.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Masuk Sekarang',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tampilan Logged In ───────────────────────────────────────
  Widget _buildLoggedIn(BuildContext context, AuthService auth) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(child: _buildHeader(context, auth)),

        // Menu items
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              children: [
                // ─── Akun ──────────────────────────────────────
                _buildSectionLabel(context, 'Akun'),
                _buildMenuCard(context, [
                  _MenuItem(
                    icon: Icons.receipt_long_rounded,
                    color: AppTheme.primary,
                    title: 'Pesanan Saya',
                    subtitle: 'Lihat riwayat & status pesanan',
                    onTap: () => _requireLogin(
                      context,
                      auth,
                      () => Navigator.of(context).pushNamed('/pesanan'),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.phone_rounded, // ← tambah ini
                    color: Colors.teal,
                    title: 'Nomor Kontak',
                    subtitle: 'Kelola nomor yang bisa dihubungi',
                    onTap: () => _requireLogin(
                      context,
                      auth,
                      () => Navigator.of(context).pushNamed('/kontak'),
                    ),
                  ),

                  _MenuItem(
                    icon: Icons.location_on_rounded,
                    color: Colors.green,
                    title: 'Kelola Alamat',
                    subtitle: 'Tambah atau ubah alamat tersimpan',
                    onTap: () => _requireLogin(
                      context,
                      auth,
                      () => Navigator.of(context).pushNamed('/alamat'),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // ─── Bantuan ───────────────────────────────────
                _buildSectionLabel(context, 'Bantuan'),
                _buildMenuCard(context, [
                  _MenuItem(
                    icon: Icons.headset_mic_rounded,
                    color: Colors.teal,
                    title: 'Dukungan Langsung',
                    subtitle: 'Chat via WhatsApp dengan tim kami',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'WhatsApp',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () => _launchWhatsApp(context),
                  ),
                ]),

                const SizedBox(height: 16),

                // ─── Informasi ─────────────────────────────────
                _buildSectionLabel(context, 'Informasi'),
                _buildMenuCard(context, [
                  _MenuItem(
                    icon: Icons.info_outline_rounded,
                    color: Colors.blueGrey,
                    title: 'Tentang Aplikasi',
                    subtitle: 'Versi & informasi aplikasi',
                    onTap: () => _showAboutDialog(context),
                  ),
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    color: Colors.orange,
                    title: 'Kebijakan Privasi',
                    subtitle: 'Cara kami melindungi data Anda',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/privacy-policy'),
                  ),
                ]),

                const SizedBox(height: 16),

                // ─── Logout ────────────────────────────────────
                _buildMenuCard(context, [
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    color: Colors.red,
                    title: 'Keluar',
                    subtitle: 'Keluar dari akun Anda',
                    titleColor: Colors.red,
                    onTap: () => _confirmLogout(context, auth),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Header Profile ───────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AuthService auth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: DecorationImage(
                    image: NetworkImage(
                      auth.user?.avatar ?? 'https://i.pravatar.cc/150?img=3',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Nama
              Text(
                auth.user?.name ?? '',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // Email
              Text(
                auth.user?.email ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),

              // Badge role
              if (auth.user?.role != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    auth.user!.role!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section Label ────────────────────────────────────────────
  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // ─── Menu Card ────────────────────────────────────────────────
  Widget _buildMenuCard(BuildContext context, List<_MenuItem> items) {
    return Container(
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
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              _buildMenuItem(context, item),
              if (index < items.length - 1)
                Divider(height: 1, indent: 60, color: Colors.grey.shade100),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 14),

            // Title & subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: item.titleColor ?? AppTheme.onSurface,
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            // Trailing / arrow
            item.trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────
  void _requireLogin(
    BuildContext context,
    AuthService auth,
    VoidCallback action,
  ) {
    if (!auth.isLoggedIn) {
      Navigator.of(context).pushNamed('/login');
    } else {
      action();
    }
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    const phone = '085186846250';
    const message = 'Halo Dikari, saya butuh bantuan mengenai layanan AC.';
    final uri = Uri.parse(
      'https://wa.me/62${phone.substring(1)}?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp tidak ditemukan di perangkat ini.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.ac_unit_rounded,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Dikari AC',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Versi 1.0.0',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              'Solusi layanan AC terpercaya — cuci, perbaikan, dan instalasi AC di genggaman Anda.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '© 2025 Dikari. All rights reserved.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthService auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: Colors.red.shade400,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Keluar dari Akun?',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda akan keluar dari akun Dikari.\nLogin lagi kapan saja.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await auth.signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Keluar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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

// ─── Model internal untuk menu item ──────────────────────────────
class _MenuItem {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    required this.onTap,
  });
}

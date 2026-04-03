import 'package:flutter/material.dart';
import '../core/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Kebijakan Privasi'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSection(
            context,
            title: 'Informasi yang Kami Kumpulkan',
            content:
                'Kami mengumpulkan informasi yang Anda berikan secara langsung, seperti nama, alamat email, dan foto profil saat Anda masuk menggunakan akun Google. Kami juga mengumpulkan data lokasi perangkat Anda untuk menampilkan informasi layanan yang relevan di area Anda.',
          ),
          _buildSection(
            context,
            title: 'Cara Kami Menggunakan Informasi',
            content:
                'Informasi yang kami kumpulkan digunakan untuk menyediakan, memelihara, dan meningkatkan layanan kami. Kami menggunakan data Anda untuk memproses pesanan, mengirimkan notifikasi terkait layanan, dan meningkatkan pengalaman pengguna di aplikasi Dikari.',
          ),
          _buildSection(
            context,
            title: 'Berbagi Informasi',
            content:
                'Kami tidak menjual, memperdagangkan, atau menyewakan informasi pribadi Anda kepada pihak ketiga. Data Anda hanya dibagikan kepada mitra teknisi yang diperlukan untuk memproses pesanan layanan Anda.',
          ),
          _buildSection(
            context,
            title: 'Keamanan Data',
            content:
                'Kami menerapkan langkah-langkah keamanan yang sesuai untuk melindungi informasi pribadi Anda dari akses, perubahan, pengungkapan, atau penghancuran yang tidak sah. Token autentikasi disimpan secara aman di perangkat Anda.',
          ),
          _buildSection(
            context,
            title: 'Data Lokasi',
            content:
                'Aplikasi Dikari meminta akses lokasi untuk menampilkan lokasi Anda di beranda. Data lokasi tidak disimpan di server kami dan hanya digunakan secara lokal di perangkat Anda.',
          ),
          _buildSection(
            context,
            title: 'Hak Anda',
            content:
                'Anda berhak untuk mengakses, memperbarui, atau menghapus informasi pribadi Anda kapan saja. Untuk menghapus akun dan semua data terkait, silakan hubungi tim dukungan kami melalui WhatsApp.',
          ),
          _buildSection(
            context,
            title: 'Perubahan Kebijakan',
            content:
                'Kami dapat memperbarui kebijakan privasi ini dari waktu ke waktu. Kami akan memberi tahu Anda tentang perubahan apa pun dengan memposting kebijakan privasi baru di halaman ini. Perubahan berlaku segera setelah diposting.',
          ),
          _buildSection(
            context,
            title: 'Hubungi Kami',
            content:
                'Jika Anda memiliki pertanyaan tentang kebijakan privasi ini, silakan hubungi kami melalui fitur Dukungan Langsung di halaman Profil atau kirim email ke support@dikari.id.',
          ),
          const SizedBox(height: 8),
          Text(
            'Terakhir diperbarui: Januari 2025',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

// ─── Feature Flags ───────────────────────────────────────────────
const bool _showDikariPay = true;
const bool _showWeatherCard = false;
// ─────────────────────────────────────────────────────────────────

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({Key? key}) : super(key: key);

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  String _lokasi = 'Memuat lokasi...';
  bool _loadingLokasi = true;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _lokasi = 'GPS tidak aktif';
          _loadingLokasi = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _lokasi = 'Izin lokasi ditolak';
            _loadingLokasi = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _lokasi = 'Izin lokasi diblokir';
          _loadingLokasi = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String subLocality = place.subLocality ?? '';
        String locality = place.locality ?? '';
        String hasil = [
          subLocality,
          locality,
        ].where((s) => s.isNotEmpty).join(', ');

        setState(() {
          _lokasi = hasil.isNotEmpty ? hasil : 'Lokasi ditemukan';
          _loadingLokasi = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lokasi = 'Gagal mendapat lokasi';
        _loadingLokasi = false;
      });
    }
  }

  void _requireLogin(BuildContext context, VoidCallback action) {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) {
      Navigator.of(context).pushNamed('/login');
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: 100,
          bottom: 32,
          left: 16,
          right: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(context),
            const SizedBox(height: 16),

            if (_showDikariPay) ...[
              _buildWalletCard(context),
              const SizedBox(height: 24),
            ],

            if (_showWeatherCard) ...[
              _buildWeatherCard(context),
              const SizedBox(height: 24),
            ],

            _buildServiceGrid(context),
            const SizedBox(height: 24),
            _buildPromoCarousel(context),
            const SizedBox(height: 24),
            _buildTestimonials(context),
          ],
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64.0),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            color: AppTheme.surface.withOpacity(0.8),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _loadingLokasi
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.primary,
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              if (!mounted) return;
                              setState(() {
                                _loadingLokasi = true;
                                _lokasi = 'Memuat lokasi...';
                              });
                              _getLocation();
                            },
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppTheme.primary,
                              size: 28,
                            ),
                          ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOKASI ANDA',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppTheme.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                        ),
                        Text(
                          _lokasi,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppTheme.primary,
                                fontSize: 14,
                                height: 1.2,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),

                Consumer<AuthService>(
                  builder: (context, auth, _) {
                    if (auth.isLoggedIn && auth.user != null) {
                      return GestureDetector(
                        onTap: () => _showProfileMenu(context, auth),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            image: DecorationImage(
                              image: NetworkImage(
                                auth.user!.avatar ??
                                    'https://i.pravatar.cc/150?img=3',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    }

                    return GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/login'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Masuk',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Profile popup menu ───────────────────────────────────────
  void _showProfileMenu(BuildContext context, AuthService auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(
                auth.user!.avatar ?? 'https://i.pravatar.cc/150?img=3',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              auth.user!.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              auth.user!.email,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await auth.signOut();
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text(
                  'Keluar',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: Colors.red.shade200),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Greeting ─────────────────────────────────────────────────
  Widget _buildGreeting(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          final String greeting = _getGreeting();

          if (!auth.isLoggedIn) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting 👋',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Masuk untuk pengalaman yang lebih personal.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/login'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Masuk Sekarang',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final firstName = auth.user!.name.split(' ').first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName 👋',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Udara sejuk bikin hari makin produktif.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  // ─── DikariPay Card (hidden) ──────────────────────────────────
  Widget _buildWalletCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppTheme.primaryFixed,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SALDO DIKARIPAY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.primaryFixed,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Consumer<AuthService>(
                builder: (context, auth, _) {
                  final balance = auth.user?.balance ?? 0;
                  final formatted =
                      'Rp ' +
                      balance
                          .toStringAsFixed(0)
                          .replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (m) => '${m[1]}.',
                          );
                  return Text(
                    formatted,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 25,
                    ),
                  );
                },
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () => _requireLogin(
              context,
              () => Navigator.of(context).pushNamed('/dikaripay'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceContainerLowest,
              foregroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              elevation: 4,
            ),
            child: const Text(
              'Isi Saldo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Weather Card ─────────────────────────────────────────────
  Widget _buildWeatherCard(BuildContext context) {
    const double temperature = 34;
    const String condition = 'Cerah Berawan';
    const String humidity = '78%';
    const String windSpeed = '12 km/h';
    const bool isHotWeather = temperature >= 32;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        gradient: LinearGradient(
          colors: isHotWeather
              ? [const Color(0xFFFF6B35), const Color(0xFFFF8E53)]
              : [const Color(0xFF42B4F5), const Color(0xFF1A8FD1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isHotWeather
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF42B4F5))
                    .withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cuaca Sekarang',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${temperature.toInt()}°',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 52,
                              height: 1,
                            ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'C',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    condition,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                isHotWeather ? '☀️' : '⛅',
                style: const TextStyle(fontSize: 64),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildWeatherDetail(
                context,
                Icons.water_drop_rounded,
                humidity,
                'Kelembaban',
              ),
              const SizedBox(width: 20),
              _buildWeatherDetail(
                context,
                Icons.air_rounded,
                windSpeed,
                'Angin',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('🧊', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isHotWeather
                        ? 'Suhu panas! Waktunya cuci AC biar makin dingin.'
                        : 'Cuaca sejuk, tapi AC tetap perlu dirawat rutin.',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _requireLogin(context, () {}),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Pesan',
                      style: TextStyle(
                        color: isHotWeather
                            ? const Color(0xFFFF6B35)
                            : AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetail(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Service Grid ─────────────────────────────────────────────
  Widget _buildServiceGrid(BuildContext context) {
    final services = [
      {
        'title': 'Cuci Reguler',
        'icon': Icons.ac_unit_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'Cuci Langganan',
        'icon': Icons.event_repeat_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Perbaikan',
        'icon': Icons.build_rounded,
        'color': Colors.orange,
      },
      {
        'title': 'Pasang Baru',
        'icon': Icons.add_box_rounded,
        'color': Colors.purple,
      },
      {
        'title': 'Relokasi',
        'icon': Icons.call_made_rounded,
        'color': Colors.red,
      },
      {
        'title': 'Beli + Pasang',
        'icon': Icons.shopping_cart_checkout_rounded,
        'color': Colors.teal,
      },
      {
        'title': 'AC Industri',
        'icon': Icons.factory_rounded,
        'color': Colors.blueGrey,
      },
      {
        'title': 'Lainnya',
        'icon': Icons.grid_view_rounded,
        'color': Colors.grey,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: services
                .sublist(0, 4)
                .map((s) => _buildServiceItem(context, s))
                .toList(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: services
                .sublist(4, 8)
                .map((s) => _buildServiceItem(context, s))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, Map<String, Object> service) {
    final Color iconColor = service['color'] as Color;
    return GestureDetector(
      onTap: () => _requireLogin(context, () {
        final title = service['title'] as String;
        if (title == 'Cuci Reguler') {
          Navigator.of(context).pushNamed('/order');
        }
      }),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14.0),
              ),
              child: Icon(
                service['icon'] as IconData,
                color: iconColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              service['title'] as String,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Promo Carousel ───────────────────────────────────────────
  Widget _buildPromoCarousel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Promo & Tips',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                'Lihat Semua',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _buildPromoCard(
                context,
                color: AppTheme.primary,
                label: 'HOT PROMO',
                title: 'Promo Cuci AC\nhemat 20%',
                subtitle: 'Gunakan kode: DINGINHEMAT',
                icon: Icons.ac_unit_rounded,
              ),
              const SizedBox(width: 16),
              _buildPromoCard(
                context,
                color: AppTheme.secondary,
                title: 'Tips merawat AC\nagar awet',
                subtitle: 'Pelajari caranya di sini',
                icon: Icons.tips_and_updates_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromoCard(
    BuildContext context, {
    required Color color,
    String? label,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (label != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: Colors.white.withOpacity(0.3), size: 64),
        ],
      ),
    );
  }

  // ─── Testimonials ─────────────────────────────────────────────
  Widget _buildTestimonials(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Text(
            'Testimoni Pelanggan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        _buildTestimonialItem(
          context,
          initials: 'AN',
          name: 'Andi Nurrahman',
          service: 'Layanan: Cuci Reguler',
          stars: 5,
          text:
              '"Teknisinya sangat sopan dan pengerjaannya sangat bersih. Gak ada air menetes sama sekali di lantai. Mantap Dikari!"',
          borderColor: AppTheme.secondary,
        ),
        const SizedBox(height: 16),
        _buildTestimonialItem(
          context,
          initials: 'SM',
          name: 'Siska Maryati',
          service: 'Layanan: Pasang Baru',
          stars: 4,
          text:
              '"Respon cepat, pengerjaan instalasi rapi banget. Harga transparan sejak awal. Rekomendasi buat yang mau pasang AC baru."',
          borderColor: AppTheme.primary,
        ),
      ],
    );
  }

  Widget _buildTestimonialItem(
    BuildContext context, {
    required String initials,
    required String name,
    required String service,
    required int stars,
    required String text,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16.0),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.surfaceContainerHighest,
                    foregroundColor: AppTheme.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        service,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

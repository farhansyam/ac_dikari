import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

// ─── Feature Flags ───────────────────────────────────────────────
const bool _showDikariPay = true;
const bool _showWeatherCard = false;
// ─────────────────────────────────────────────────────────────────

class ReviewModel {
  final int id;
  final int rating;
  final String review;
  final String customerName;
  final String? customerAvatar;
  final String technicianName;
  final String createdAt;

  ReviewModel({
    required this.id,
    required this.rating,
    required this.review,
    required this.customerName,
    this.customerAvatar,
    required this.technicianName,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'],
      rating: json['rating'],
      review: json['review'] ?? '',
      customerName: json['customer_name'] ?? 'Customer',
      customerAvatar: json['customer_avatar'],
      technicianName: json['technician_name'] ?? 'Teknisi',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({Key? key}) : super(key: key);

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> with RouteAware {
  String _lokasi = 'Memuat lokasi...';
  bool _loadingLokasi = true;
  List<ReviewModel> _reviews = [];
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _loadReviews();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthService>().refreshUser();
    });
  }

  Future<void> _refreshData() async {
    await Future.wait([
      context.read<AuthService>().refreshUser(),
      _loadReviews(),
    ]);
  }

  Future<void> _loadReviews() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/reviews'),
        headers: {'Accept': 'application/json'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _reviews = (data['reviews'] as List)
              .map((e) => ReviewModel.fromJson(e))
              .toList();
          _loadingReviews = false;
        });
      } else {
        setState(() => _loadingReviews = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReviews = false);
    }
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
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
            onPressed: () => _requireLogin(context, () {
              Navigator.of(context).pushNamed('/dikaripay').then((_) {
                if (mounted) context.read<AuthService>().refreshUser();
              });
            }),
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

  Widget _buildServiceGrid(BuildContext context) {
    final services = [
      {
        'title': 'Cuci Reguler',
        'image': 'assets/images/services/cuci_reguler.png',
        'route': '/order',
      },
      {
        'title': 'Cuci Langganan',
        'image': 'assets/images/services/cuci_langganan.png',
        'route': null,
      },
      {
        'title': 'Perbaikan',
        'image': 'assets/images/services/perbaikan.png',
        'route': null,
      },
      {
        'title': 'Pasang Baru',
        'image': 'assets/images/services/pasang_baru.png',
        'route': '/order',
      },
      {
        'title': 'Relokasi',
        'image': 'assets/images/services/relokasi.png',
        'route': '/order',
      },
      {
        'title': 'Beli + Pasang',
        'image': 'assets/images/services/beli_pasang.png',
        'route': null,
      },
      {
        'title': 'AC Industri',
        'image': 'assets/images/services/ac_industri.png',
        'route': null,
      },
      {
        'title': 'Lainnya',
        'image': 'assets/images/services/lainnya.png',
        'route': null,
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

  Widget _buildServiceItem(BuildContext context, Map<String, Object?> service) {
    final String? route = service['route'] as String?;
    final String imagePath = service['image'] as String;

    return GestureDetector(
      onTap: () => _requireLogin(context, () {
        if (route != null) {
          Navigator.of(context).pushNamed(route).then((_) {
            if (mounted) context.read<AuthService>().refreshUser();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Segera hadir!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color.fromARGB(0, 255, 255, 255),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  // Shadow bawah — efek utama 3D
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  // Shadow kanan — kesan kedalaman
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(4, 4),
                    spreadRadius: 0,
                  ),
                  // Highlight atas kiri — efek cahaya
                  BoxShadow(
                    color: Colors.white.withOpacity(0.9),
                    blurRadius: 4,
                    offset: const Offset(-2, -2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Image.asset(
                  imagePath,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
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

  // ─── Testimonials (dari API) ──────────────────────────────────
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
        if (_loadingReviews)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_reviews.isEmpty)
          // Fallback hardcode kalau belum ada review
          Column(
            children: [
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
          )
        else
          Column(
            children: _reviews.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i < _reviews.length - 1 ? 16 : 0,
                ),
                child: _buildTestimonialFromApi(context, r),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTestimonialFromApi(BuildContext context, ReviewModel review) {
    final borderColors = [
      AppTheme.secondary,
      AppTheme.primary,
      Colors.teal,
      Colors.purple,
      Colors.orange,
    ];
    final borderColor = borderColors[review.id % borderColors.length];
    final initials = review.customerName.isNotEmpty
        ? review.customerName[0].toUpperCase()
        : 'C';

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
            children: [
              review.customerAvatar != null
                  ? CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(review.customerAvatar!),
                      onBackgroundImageError: (_, __) {},
                    )
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      foregroundColor: AppTheme.primary,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Teknisi: ${review.technicianName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"${review.review}"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            review.createdAt,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
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
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.surfaceContainerHighest,
                foregroundColor: AppTheme.primary,
                child: Text(
                  initials,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 14,
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

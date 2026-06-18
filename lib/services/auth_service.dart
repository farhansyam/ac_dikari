import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart'; // ← tambah import

class UserModel {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final String? role;
  final double balance; // ← tambah
  final double avgRating;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.role,
    this.balance = 0,
    required this.avgRating,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatar: json['avatar'],
      role: json['role'],
      balance: (json['balance'] as num? ?? 0).toDouble(),
      avgRating: (json['avg_rating'] as num? ?? 0).toDouble(), // ← tambah
    );
  }
}

class AuthService extends ChangeNotifier {
  // ─── Ganti dengan base URL backend Laravel kamu ───────────────
  // static const String _baseUrl = 'http://10.0.2.2:8000/api';
  // static const String _baseUrl = 'http://10.18.40.17:8000/api';
  static const String _baseUrl = 'https://acdikari.app/api';
  static String get baseUrl => _baseUrl; // ← tambah ini
  static const String _wilayahBase = 'https://acdikari.app';

  // ─────────────────────────────────────────────────────────────

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null && _user != null;
  String? get errorMessage => _errorMessage;

  // ─── Init: cek apakah sudah login sebelumnya ──────────────────
  Future<void> init() async {
    _token = await _storage.read(key: 'auth_token');
    if (_token != null) {
      await _fetchMe();
      await _saveFcmToken(); // ←
    }
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = UserModel.fromJson(data['user']);
        notifyListeners();
      }
    } catch (_) {}
  }

  // ─── Google Sign In ───────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();

      if (googleAccount == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleAccount.authentication;

      final String? accessToken = googleAuth.accessToken;

      if (accessToken == null) {
        throw Exception('Tidak dapat mengambil access token dari Google.');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Device-Type': 'mobile',
        },
        body: jsonEncode({'google_token': accessToken}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _token = data['token'];
        _user = UserModel.fromJson(data['user']);
        await _storage.write(key: 'auth_token', value: _token);
        await _saveFcmToken(); // ← tambah di sini
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Login gagal.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Apple Sign In ────────────────────────────────────────────
  String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Gabungkan nama (Apple kirim terpisah: givenName + familyName)
      final fullName = [
        appleCredential.givenName ?? '',
        appleCredential.familyName ?? '',
      ].where((s) => s.isNotEmpty).join(' ');

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/apple'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Device-Type': 'mobile',
        },
        body: jsonEncode({
          'identity_token': appleCredential.identityToken,
          'user_identifier': appleCredential.userIdentifier,
          if (appleCredential.email != null) 'email': appleCredential.email,
          if (fullName.isNotEmpty) 'full_name': fullName,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _token = data['token'];
        _user = UserModel.fromJson(data['user']);
        await _storage.write(key: 'auth_token', value: _token);
        await _saveFcmToken();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Login Apple gagal.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _saveFcmToken() async {
    try {
      final fcmToken = await NotificationService().getToken();
      debugPrint('=== FCM TOKEN: $fcmToken');
      debugPrint('=== AUTH TOKEN: $_token');

      if (fcmToken == null || _token == null) {
        debugPrint('=== FCM SKIP: token null');
        return;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );

      debugPrint('=== FCM RESPONSE: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('=== FCM ERROR: $e');
    }
  }

  // ─── Fetch data user dari backend ────────────────────────────
  Future<void> _fetchMe() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = UserModel.fromJson(data['user']);
      } else {
        // Token tidak valid, hapus
        await _clearSession();
      }
    } catch (e) {
      await _clearSession();
    }
  }

  // ─── Logout ───────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      if (_token != null) {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
          },
        );
      }
    } catch (_) {}

    await _googleSignIn.signOut();
    await _clearSession();
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    await _storage.delete(key: 'auth_token');
    notifyListeners();
  }
}

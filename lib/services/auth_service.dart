import 'dart:convert';
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

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.role,
    this.balance = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatar: json['avatar'],
      role: json['role'],
      balance: (json['balance'] as num? ?? 0).toDouble(), // ← tambah
    );
  }
}

class AuthService extends ChangeNotifier {
  // ─── Ganti dengan base URL backend Laravel kamu ───────────────
  // static const String _baseUrl = 'http://10.0.2.2:8000/api';
  // static const String _baseUrl = 'http://10.18.40.17:8000/api';
  static const String _baseUrl =
      'https://noegenetic-jiggly-lulu.ngrok-free.dev/api';
  static String get baseUrl => _baseUrl; // ← tambah ini
  static const String _wilayahBase =
      'https://noegenetic-jiggly-lulu.ngrok-free.dev';

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

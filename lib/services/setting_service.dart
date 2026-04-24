// lib/services/setting_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingService {
  static Future<Map<String, String>> getWaSettings() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/settings/wa'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'wa_ac_industri': data['wa_ac_industri'] ?? '',
          'wa_cs': data['wa_cs'] ?? '',
          'wa_message_ac_industri': data['wa_message_ac_industri'] ?? '',
          'wa_message_cs': data['wa_message_cs'] ?? '',
        };
      }
    } catch (_) {}
    return {};
  }

  static Future<void> openWhatsApp(String phone, String message) async {
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$phone?text=$encoded');
    // ignore: import_of_legacy_library_into_null_safe
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

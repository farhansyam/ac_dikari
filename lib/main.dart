import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/address_screen.dart';
import 'screens/phone_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService()..init(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AC Dikari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/home': (_) => const HomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/privacy-policy': (_) => const PrivacyPolicyScreen(),
        '/alamat': (_) => const AddressScreen(),
        '/kontak': (_) => const PhoneScreen(),
      },
    );
  }
}

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
import 'screens/order_flow_screen.dart';
import 'screens/payment_screen.dart';
import 'services/order_service.dart'; // ← tambah ini
import 'package:flutter_localizations/flutter_localizations.dart'; // ← tambah
import 'screens/pesanan_screen.dart';

// Di routes:
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
      // ← tambah ini
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      locale: const Locale('id', 'ID'),

      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/home': (_) => const HomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/privacy-policy': (_) => const PrivacyPolicyScreen(),
        '/alamat': (_) => const AddressScreen(),
        '/kontak': (_) => const PhoneScreen(),
        '/order': (_) => const OrderFlowScreen(),
        '/pesanan': (_) => const PesananScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/payment') {
          final order = settings.arguments as OrderModel;
          return MaterialPageRoute(builder: (_) => PaymentScreen(order: order));
        }
        return null;
      },
    );
  }
}

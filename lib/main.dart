import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/order_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/address_screen.dart';
import 'screens/phone_screen.dart';
import 'screens/order_flow_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/pesanan_screen.dart';
import 'screens/dikaripay_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/complaint_screen.dart';

// ─── Background handler ───────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService().init();

  GoogleFonts.config.allowRuntimeFetching = true;

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

      navigatorKey: NotificationService.navigatorKey,

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
        '/pesanan': (_) => const PesananScreen(),
        '/dikaripay': (_) => const DikariPayScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/payment') {
          final order = settings.arguments as OrderModel;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => PaymentScreen(order: order),
          );
        }
        // Di onGenerateRoute:
        if (settings.name == '/rating') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => RatingScreen(
              orderId: args['orderId'],
              technicianName: args['technicianName'],
              secondTechnicianName: args['secondTechnicianName'],
              splitTechnician: args['splitTechnician'] ?? false,
            ),
          );
        }
        if (settings.name == '/complaint') {
          final orderId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (_) => ComplaintScreen(orderId: orderId),
          );
        }
        if (settings.name == '/order') {
          return MaterialPageRoute(
            builder: (_) =>
                const OrderFlowScreen(orderType: OrderType.cuciReguler),
          );
        }
        if (settings.name == '/pasang-baru') {
          return MaterialPageRoute(
            builder: (_) =>
                const OrderFlowScreen(orderType: OrderType.pasangBaru),
          );
        }
        if (settings.name == '/beli-pasang') {
          return MaterialPageRoute(
            builder: (_) =>
                const OrderFlowScreen(orderType: OrderType.beliPasang),
          );
        }
        if (settings.name == '/relokasi') {
          return MaterialPageRoute(
            builder: (_) =>
                const OrderFlowScreen(orderType: OrderType.relokasi),
          );
        }
        if (settings.name == '/perbaikan') {
          return MaterialPageRoute(
            builder: (_) =>
                const OrderFlowScreen(orderType: OrderType.perbaikan),
          );
        }
        return null;
      },
    );
  }
}

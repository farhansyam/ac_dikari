import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../core/theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ─── Logo & Brand ──────────────────────────────
              Image.asset(
                'assets/images/logo_acd.png',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Text(
                'Solusi AC Terpercaya\ndi Genggaman Anda',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 2),

              // ─── Error message ─────────────────────────────
              Consumer<AuthService>(
                builder: (context, auth, _) {
                  if (auth.errorMessage == null) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade400,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ─── Google Sign In Button ─────────────────────
              Consumer<AuthService>(
                builder: (context, auth, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              final success = await auth.signInWithGoogle();
                              if (success && context.mounted) {
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed('/home');
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        elevation: 2,
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://www.google.com/favicon.ico',
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.g_mobiledata,
                                    size: 22,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Masuk dengan Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              Text(
                'Dengan masuk, Anda menyetujui\nSyarat & Ketentuan serta Kebijakan Privasi kami.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

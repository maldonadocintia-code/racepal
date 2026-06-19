import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_provider.dart';
import '../theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Logo
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  boxShadow: [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.bolt,
                  size: 52,
                  color: c.textOnVolt,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: AppType.xxxxl,
                  color: c.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your UK running social calendar',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: AppType.md,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              // Feature bullets
              _featureRow(context, Icons.bolt, 'Track races & parkruns'),
              const SizedBox(height: 12),
              _featureRow(context, Icons.people, 'Follow friends, see their runs'),
              const SizedBox(height: 12),
              _featureRow(context, Icons.star, 'Rate with ⚡ lightning reviews'),
              const Spacer(flex: 2),
              // Google sign in
              if (provider.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.statusError.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    'Sign in failed. Please try again.',
                    style: TextStyle(color: c.statusError, fontSize: AppType.sm),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      provider.loading ? null : provider.signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: provider.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://developers.google.com/identity/images/g-logo.png',
                              height: 22,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.g_mobiledata,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontFamily: AppType.body,
                                fontSize: AppType.md,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Text.rich(
                TextSpan(
                  text: 'By continuing you agree to our ',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: AppType.sm,
                  ),
                  children: [
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: c.textLink,
                        fontSize: AppType.sm,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(
                              Uri.parse(AppConstants.privacyPolicyUrl),
                              mode: LaunchMode.externalApplication,
                            ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(BuildContext context, IconData icon, String text) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.primaryMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: c.textPrimary, size: 18),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: TextStyle(color: c.textPrimary, fontSize: AppType.base),
        ),
      ],
    );
  }
}

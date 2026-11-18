import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'phone_login_screen.dart';
import 'signup/sign_up_setup_screen.dart';

/// First screen for signed-out users: the logo and the two ways in.
///
/// Scrolls instead of overflowing on short or landscape screens.
class WelcomeGatewayScreen extends StatelessWidget {
  const WelcomeGatewayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),
                        const _Brand(),
                        const SizedBox(height: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'أهلاً بيك في خزين',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'اطلب نواقص محلك بسعر الجملة من الشركات مباشرة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PhoneLoginScreen(),
                                ),
                              ),
                              child: const Text('تسجيل الدخول'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignUpSetupScreen(),
                                ),
                              ),
                              child: const Text('إنشاء حساب جديد'),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'أسعار جملة · توصيل مجاني · الدفع عند الاستلام',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(
            'assets/images/logo.png',
            width: 128,
            height: 128,
            semanticLabel: 'خزين',
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'خزين',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const Text(
          'كل نواقص محلك في مكان واحد',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

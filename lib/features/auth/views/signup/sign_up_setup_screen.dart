import 'package:flutter/material.dart';

import '../phone_entry_screen.dart';
import '../phone_login_screen.dart';
import 'otp_verification_screen.dart';

/// Sign-up: verify the merchant's phone number, then the registration
/// wizard collects the store details.
class SignUpSetupScreen extends StatelessWidget {
  const SignUpSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PhoneEntryScreen(
      purpose: OtpPurpose.signUp,
      title: 'إنشاء حساب جديد',
      subtitle: 'اكتب رقم الموبايل اللي هتستلم عليه الطلبات',
      switchQuestion: 'عندك حساب؟',
      switchAction: 'تسجيل الدخول',
      switchTo: (_) => const PhoneLoginScreen(),
    );
  }
}

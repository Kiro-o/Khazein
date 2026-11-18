import 'package:flutter/material.dart';

import 'phone_entry_screen.dart';
import 'signup/otp_verification_screen.dart';
import 'signup/sign_up_setup_screen.dart';

/// Merchant login by phone number and SMS code (no password).
///
/// An unregistered number is told so after the code, and can create an
/// account from there (see [OtpPurpose.login]).
class PhoneLoginScreen extends StatelessWidget {
  const PhoneLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PhoneEntryScreen(
      purpose: OtpPurpose.login,
      title: 'تسجيل الدخول',
      subtitle: 'اكتب رقم موبايلك اللي مسجّل بيه في خزين',
      switchQuestion: 'مش عندك حساب؟',
      switchAction: 'إنشاء حساب جديد',
      switchTo: (_) => const SignUpSetupScreen(),
    );
  }
}

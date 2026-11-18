import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';
import 'signup/otp_verification_screen.dart';

/// Validates [rawPhone], sends the SMS code and opens [OtpVerificationScreen]
/// for [purpose].
///
/// Returns an Arabic error message to show, or null on success.
Future<String?> requestOtpAndOpenVerification(
  BuildContext context,
  String rawPhone, {
  required OtpPurpose purpose,
}) async {
  final phone = Validators.normalizeNumbers(rawPhone)
      .replaceAll(RegExp(r'[\s\-]'), '');
  final phoneError = Validators.validateEgyptianPhone(phone);
  if (phoneError != null) return phoneError;

  final PhoneVerification verification;
  try {
    verification = await AuthRepository.instance.sendOtp(phone);
  } on AuthFailure catch (e) {
    return e.message;
  }

  if (!context.mounted) return null;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => OtpVerificationScreen(
        verification: verification,
        purpose: purpose,
      ),
    ),
  );
  return null;
}

import 'package:flutter/widgets.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../home/views/merchant_home_screen.dart';
import 'registration/merchant_registration_screen.dart';

/// Screen for the signed-in user: the home screen when `users/{uid}` exists,
/// otherwise the merchant registration wizard.
///
/// Throws [AuthFailure] when the profile cannot be loaded or the account is
/// not a merchant.
Future<Widget> signedInDestination() async {
  final merchant = await AuthRepository.instance.loadCurrentMerchant();
  if (merchant != null) return MerchantHomeScreen(merchant: merchant);
  return const MerchantRegistrationScreen();
}

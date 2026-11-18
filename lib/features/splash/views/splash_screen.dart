import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/views/signed_in_destination.dart';
import '../../auth/views/welcome_gateway_screen.dart';

/// Startup screen: the Khazeen logo while the session is restored.
///
/// Kept static (no video or animation) so it is quick on low-end phones.
/// Routes to:
/// - the home screen for a signed-in merchant with a profile,
/// - the registration wizard for a signed-in number without a profile,
/// - [WelcomeGatewayScreen] when signed out or the profile can't be loaded.
class SplashScreen extends StatefulWidget {
  /// Shortest time the logo stays on screen, so it doesn't just flash.
  final Duration minimumDuration;

  const SplashScreen({
    super.key,
    this.minimumDuration = const Duration(milliseconds: 700),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openDestination();
  }

  Future<void> _openDestination() async {
    final results = await Future.wait([
      _resolveDestination(),
      Future<void>.delayed(widget.minimumDuration),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => results.first as Widget,
        transitionDuration: Duration.zero,
      ),
    );
  }

  Future<Widget> _resolveDestination() async {
    try {
      if (AuthRepository.instance.currentUser == null) {
        return const WelcomeGatewayScreen();
      }
      return await signedInDestination();
    } catch (e) {
      debugPrint('Session restore failed: $e');
      return const WelcomeGatewayScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.logoGreen,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 160,
              height: 160,
              semanticLabel: 'خزين',
            ),
            const SizedBox(height: 12),
            const Text(
              'كل نواقص محلك في مكان واحد',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

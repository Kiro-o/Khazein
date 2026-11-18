import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/splash/views/splash_screen.dart';
import 'core/config/app_env.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cairo is bundled in assets/fonts (SIL Open Font License).
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Cairo font'], license);
  });
  try {
    await Firebase.initializeApp(options: AppEnv.firebaseOptions);
    // Skips reCAPTCHA / Play Integrity so the Firebase console's test phone
    // numbers can sign in without a challenge (real numbers fail in this
    // mode). On in debug with --dart-define=AUTH_TEST_MODE=true, and always
    // in the demo build, whose project only has test numbers.
    if ((kDebugMode && const bool.fromEnvironment('AUTH_TEST_MODE')) ||
        AppEnv.isDemo) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }
  // A widget that fails to build shows a short Arabic message instead of
  // a blank grey box (release) or a red error screen (debug stays red).
  if (!kDebugMode) {
    ErrorWidget.builder = (details) => const Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'حصلت مشكلة في عرض الصفحة دي. ارجع وحاول تاني.',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
  runApp(const KhazeenApp());
}

/// Khazeen (خزين) - B2B FMCG & Grocery wholesale distribution platform in Egypt.
class KhazeenApp extends StatelessWidget {
  const KhazeenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'خزين - خزين محلك بسعر الجملة',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}

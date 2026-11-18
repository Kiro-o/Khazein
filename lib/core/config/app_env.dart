import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import '../../firebase_options.dart';

/// Which Firebase project the app talks to.
///
/// Production is the default. The portfolio demo runs on a separate
/// project and is selected at build time:
///
///     flutter run --dart-define-from-file=demo/demo.env.json
///
/// where the JSON holds `KHAZEEN_ENV: demo` and the demo project's web
/// config (`DEMO_FIREBASE_*`, see demo/README.md).
abstract final class AppEnv {
  static const String name = String.fromEnvironment(
    'KHAZEEN_ENV',
    defaultValue: 'production',
  );

  static const bool isDemo = name == 'demo';

  /// The real project, which the demo must never use.
  static const String productionProjectId = 'khazeen-app-14279';

  static FirebaseOptions get firebaseOptions {
    if (!isDemo) return DefaultFirebaseOptions.currentPlatform;

    const options = FirebaseOptions(
      apiKey: String.fromEnvironment('DEMO_FIREBASE_API_KEY'),
      appId: String.fromEnvironment('DEMO_FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment(
        'DEMO_FIREBASE_MESSAGING_SENDER_ID',
      ),
      projectId: String.fromEnvironment('DEMO_FIREBASE_PROJECT_ID'),
      authDomain: String.fromEnvironment('DEMO_FIREBASE_AUTH_DOMAIN'),
      storageBucket: String.fromEnvironment('DEMO_FIREBASE_STORAGE_BUCKET'),
    );
    if (options.apiKey.isEmpty || options.projectId.isEmpty) {
      throw StateError(
        'KHAZEEN_ENV=demo needs the demo Firebase config '
        '(DEMO_FIREBASE_* in demo/demo.env.json).',
      );
    }
    if (options.projectId == productionProjectId) {
      throw StateError('The demo build must not use the production project.');
    }
    return options;
  }
}

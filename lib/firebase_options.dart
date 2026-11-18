// Firebase configuration for the `khazeen-app-14279` project.
// Written by hand (equivalent to `flutterfire configure` output).
// Android values come from android/app/google-services.json.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for '
          '$defaultTargetPlatform. Only web and Android are supported.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCycwkJXWz_2UYvqMN0jxDa2TyOqPNIdnE',
    authDomain: 'khazeen-app-14279.firebaseapp.com',
    projectId: 'khazeen-app-14279',
    storageBucket: 'khazeen-app-14279.firebasestorage.app',
    messagingSenderId: '939268156138',
    appId: '1:939268156138:web:8221e8499908f470d60593',
    measurementId: 'G-BVL803SNYZ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC7UzZbESRrWOBubpSiEskbfCs49XKDL80',
    appId: '1:939268156138:android:e5c2b21a00fbcef0d60593',
    messagingSenderId: '939268156138',
    projectId: 'khazeen-app-14279',
    storageBucket: 'khazeen-app-14279.firebasestorage.app',
  );
}

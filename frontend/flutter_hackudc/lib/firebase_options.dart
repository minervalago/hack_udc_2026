import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return web; // same project, reuse web config for desktop
      default:
        throw UnsupportedError('Plataforma no soportada.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'API_KEY',
    appId: 'APP_ID',
    messagingSenderId: 'MESSAGING_SENDER_ID',
    projectId: 'PROJECT_ID',
    authDomain: 'AUTH_DOMAIN',
    databaseURL: 'DATABASE_URL',
    storageBucket: 'STORAGE_BUCKET',
    measurementId: 'MEASUREMENT_ID',
  );
}

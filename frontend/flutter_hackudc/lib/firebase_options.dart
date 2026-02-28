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
    apiKey: 'AIzaSyD7TJ549JBG-0s-hTlp-4o7-ahuf4c-Iow',
    appId: '1:1097696584923:web:28197fce9d2f367f6398fe',
    messagingSenderId: '1097696584923',
    projectId: 'denodo-hackudc-2026',
    authDomain: 'enodo-hackudc-2026.firebaseapp.com',
    databaseURL: 'https://denodo-hackudc-2026.firebaseio.com',
    storageBucket: 'denodo-hackudc-2026.appspot.com',
    measurementId: 'G-D7TJ549JBG',
  );
}

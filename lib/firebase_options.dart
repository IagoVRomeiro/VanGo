import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD9du7jzsRwDSP4yvs7-l8DjC_x2NYjk-Q',
    appId: '1:682025937438:web:d1e65d53f23aa73c509c0f',
    messagingSenderId: '682025937438',
    projectId: 'vango-4a26d',
    authDomain: 'vango-4a26d.firebaseapp.com',
    storageBucket: 'vango-4a26d.firebasestorage.app',
    measurementId: 'G-WN7T222ZF8',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBzkpKjGUGLEvIwkO-ByhLtLaCvPoZE3N0',
    appId: '1:682025937438:android:edff6b9d91ce8c4c509c0f',
    messagingSenderId: '682025937438',
    projectId: 'vango-4a26d',
    storageBucket: 'vango-4a26d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBq_FsfH8YXoJAtBzvOrLYCXVAP0SnHbI4',
    appId: '1:682025937438:ios:2a20af4db3bb36e3509c0f',
    messagingSenderId: '682025937438',
    projectId: 'vango-4a26d',
    storageBucket: 'vango-4a26d.firebasestorage.app',
    iosBundleId: 'pucminas.br.interfaceApp2',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBq_FsfH8YXoJAtBzvOrLYCXVAP0SnHbI4',
    appId: '1:682025937438:ios:2a20af4db3bb36e3509c0f',
    messagingSenderId: '682025937438',
    projectId: 'vango-4a26d',
    storageBucket: 'vango-4a26d.firebasestorage.app',
    iosBundleId: 'pucminas.br.interfaceApp2',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD9du7jzsRwDSP4yvs7-l8DjC_x2NYjk-Q',
    appId: '1:682025937438:web:0510690e8d401302509c0f',
    messagingSenderId: '682025937438',
    projectId: 'vango-4a26d',
    authDomain: 'vango-4a26d.firebaseapp.com',
    storageBucket: 'vango-4a26d.firebasestorage.app',
    measurementId: 'G-R6R4C3DWX3',
  );

}
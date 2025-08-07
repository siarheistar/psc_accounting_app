import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD3ItZdRNszLghSkXO1_WsWEqridbMryLI',
    appId: '1:772592694172:web:5b4fc14f0d193a44abce59',
    messagingSenderId: '772592694172',
    projectId: 'psc-accounting-web',
    authDomain: 'psc-accounting-web.firebaseapp.com',
    storageBucket: 'psc-accounting-web.firebasestorage.app',
    measurementId: 'G-EPSZWHX0N4',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD3ItZdRNszLghSkXO1_WsWEqridbMryLI',
    appId: '1:772592694172:android:YOUR_ANDROID_APP_ID', // ← Update this
    messagingSenderId: '772592694172',
    projectId: 'psc-accounting-web',
    storageBucket: 'psc-accounting-web.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD3ItZdRNszLghSkXO1_WsWEqridbMryLI',
    appId: '1:772592694172:ios:YOUR_IOS_APP_ID', // ← Update this
    messagingSenderId: '772592694172',
    projectId: 'psc-accounting-web',
    storageBucket: 'psc-accounting-web.firebasestorage.app',
    iosClientId:
        '772592694172-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com', // ← Update from Firebase console
    iosBundleId: 'com.siarheistarconsulting.pscsa',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD3ItZdRNszLghSkXO1_WsWEqridbMryLI',
    appId: '1:772592694172:macos:YOUR_MACOS_APP_ID', // ← Update this
    messagingSenderId: '772592694172',
    projectId: 'psc-accounting-web',
    storageBucket: 'psc-accounting-web.firebasestorage.app',
    iosClientId:
        '772592694172-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com', // ← Update from Firebase console
    iosBundleId: 'com.siarheistarconsulting.pscsa',
  );
}

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
    apiKey: 'AIzaSyDu9dH4ZUN3wG5rt7NoPoMVSmfg8TtQPhE',
    appId: '1:933770543553:web:7060fc5223cc8be00daf40',
    messagingSenderId: '933770543553',
    projectId: 'driving-f1311',
    authDomain: 'driving-f1311.firebaseapp.com',
    storageBucket: 'driving-f1311.firebasestorage.app',
    measurementId: 'G-N2D81MWSYZ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBQoaeGYON00oiH-jhqep6uGLqBOfgdetA',
    appId: '1:933770543553:android:095192ad2c349af80daf40',
    messagingSenderId: '933770543553',
    projectId: 'driving-f1311',
    storageBucket: 'driving-f1311.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'your-ios-api-key',
    appId: 'your-ios-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'your-project-id',
    storageBucket: 'your-project.appspot.com',
    iosBundleId: 'com.yourcompany.driving',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'your-macos-api-key',
    appId: 'your-macos-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'your-project-id',
    storageBucket: 'your-project.appspot.com',
    iosBundleId: 'com.yourcompany.driving',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDu9dH4ZUN3wG5rt7NoPoMVSmfg8TtQPhE',
    appId: '1:933770543553:web:1b178df2930cb8260daf40',
    messagingSenderId: '933770543553',
    projectId: 'driving-f1311',
    authDomain: 'driving-f1311.firebaseapp.com',
    storageBucket: 'driving-f1311.firebasestorage.app',
    measurementId: 'G-XCVD82QW2L',
  );

}
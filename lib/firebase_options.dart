// ⚠️  REPLACE THIS FILE with your own Firebase configuration.
//
// Steps:
//  1. Go to https://console.firebase.google.com
//  2. Create a project (or use an existing one)
//  3. Add an Android app with package name:  com.racepal.app
//  4. Download google-services.json and place it in android/app/
//  5. Run:  flutterfire configure
//     This auto-generates the real firebase_options.dart
//
// The stub below lets the project compile so you can review the code.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. '
          'Run: flutterfire configure',
        );
    }
  }

  // 🚨 Replace ALL values below with your real Firebase project config.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC5nRfTlMTTjQMN7ipduJZrKXSS0SMrf_s',
    appId: '1:735418458967:android:29ce874c9b298cec91d412',
    messagingSenderId: '735418458967',
    projectId: 'racepal-ae334',
    storageBucket: 'racepal-ae334.firebasestorage.app',
  );
}

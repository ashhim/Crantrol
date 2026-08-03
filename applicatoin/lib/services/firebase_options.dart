import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'app_environment.dart';

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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: AppEnvironment.firebaseApiKey,
        appId: AppEnvironment.firebaseWebAppId,
        messagingSenderId: AppEnvironment.firebaseMessagingSenderId,
        projectId: AppEnvironment.firebaseProjectId,
        authDomain: AppEnvironment.firebaseAuthDomain,
        storageBucket: AppEnvironment.firebaseStorageBucket,
        databaseURL: AppEnvironment.firebaseDatabaseUrl,
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: AppEnvironment.firebaseApiKey,
        appId: AppEnvironment.firebaseWindowsAppId,
        messagingSenderId: AppEnvironment.firebaseMessagingSenderId,
        projectId: AppEnvironment.firebaseProjectId,
        authDomain: AppEnvironment.firebaseAuthDomain,
        storageBucket: AppEnvironment.firebaseStorageBucket,
        databaseURL: AppEnvironment.firebaseDatabaseUrl,
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: AppEnvironment.firebaseApiKey,
        appId: AppEnvironment.firebaseAndroidAppId,
        messagingSenderId: AppEnvironment.firebaseMessagingSenderId,
        projectId: AppEnvironment.firebaseProjectId,
        storageBucket: AppEnvironment.firebaseStorageBucket,
        databaseURL: AppEnvironment.firebaseDatabaseUrl,
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: AppEnvironment.firebaseApiKey,
        appId: AppEnvironment.firebaseIosAppId,
        messagingSenderId: AppEnvironment.firebaseMessagingSenderId,
        projectId: AppEnvironment.firebaseProjectId,
        authDomain: AppEnvironment.firebaseAuthDomain,
        storageBucket: AppEnvironment.firebaseStorageBucket,
        databaseURL: AppEnvironment.firebaseDatabaseUrl,
        iosBundleId: 'com.hashpc.app',
      );
}

import 'package:flutter/services.dart' show rootBundle;

class AppEnvironment {
  static final Map<String, String> _values = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) {
      return;
    }

    try {
      final content = await rootBundle.loadString('assets/.env');
      _parse(content);
    } catch (_) {
      try {
        final content = await rootBundle.loadString('.env');
        _parse(content);
      } catch (_) {
        // Missing env file falls back to placeholders.
      }
    }

    _loaded = true;
  }

  static void _parse(String content) {
    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      if (line.startsWith('export ')) {
        line = line.substring(7).trim();
      }

      final equalsIndex = line.indexOf('=');
      if (equalsIndex <= 0) {
        continue;
      }

      final key = line.substring(0, equalsIndex).trim();
      var value = line.substring(equalsIndex + 1).trim();

      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      _values[key] = value;
    }
  }

  static String getString(String key, {String fallback = ''}) {
    return _values[key] ?? fallback;
  }

  static String get firebaseApiKey =>
      getString('FIREBASE_API_KEY', fallback: 'PUT_YOUR_FIREBASE_API_KEY_HERE');

  static String get firebaseWebAppId => getString(
        'FIREBASE_WEB_APP_ID',
        fallback: getString(
          'FIREBASE_APP_ID',
          fallback: 'PUT_YOUR_FIREBASE_WEB_APP_ID_HERE',
        ),
      );

  static String get firebaseWindowsAppId => getString(
        'FIREBASE_WINDOWS_APP_ID',
        fallback: getString(
          'FIREBASE_APP_ID',
          fallback: firebaseWebAppId,
        ),
      );

  static String get firebaseAndroidAppId => getString(
        'FIREBASE_ANDROID_APP_ID',
        fallback: getString(
          'FIREBASE_APP_ID',
          fallback: 'PUT_YOUR_FIREBASE_ANDROID_APP_ID_HERE',
        ),
      );

  static String get firebaseIosAppId => getString(
        'FIREBASE_IOS_APP_ID',
        fallback: getString(
          'FIREBASE_APP_ID',
          fallback: 'PUT_YOUR_FIREBASE_IOS_APP_ID_HERE',
        ),
      );

  static String get firebaseAuthDomain => getString(
        'FIREBASE_AUTH_DOMAIN',
        fallback: 'PUT_YOUR_FIREBASE_AUTH_DOMAIN_HERE',
      );

  static String get firebaseDatabaseUrl => getString(
        'FIREBASE_DATABASE_URL',
        fallback: 'PUT_YOUR_FIREBASE_DATABASE_URL_HERE',
      );

  static String get firebaseProjectId => getString(
        'FIREBASE_PROJECT_ID',
        fallback: 'PUT_YOUR_FIREBASE_PROJECT_ID_HERE',
      );

  static String get firebaseStorageBucket => getString(
        'FIREBASE_STORAGE_BUCKET',
        fallback: 'PUT_YOUR_FIREBASE_STORAGE_BUCKET_HERE',
      );

  static String get firebaseMessagingSenderId => getString(
        'FIREBASE_MESSAGING_SENDER_ID',
        fallback: 'PUT_YOUR_FIREBASE_MESSAGING_SENDER_ID_HERE',
      );
}

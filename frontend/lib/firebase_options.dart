import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase configuration supplied at build time:
///
/// flutter run \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_PROJECT_ID=... \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///   --dart-define=FIREBASE_ANDROID_APP_ID=... \
///   --dart-define=GOOGLE_WEB_CLIENT_ID=...
///
/// Alternatively run `flutterfire configure` and replace this file with the
/// generated one.
class DefaultFirebaseOptions {
  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static const String _fallbackAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: _fallbackAppId);
  static const String _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: _fallbackAppId);
  static const String _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: _fallbackAppId);

  static const String androidClientId = String.fromEnvironment('GOOGLE_ANDROID_CLIENT_ID');
  static const String iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const String webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static bool get _commonConfigured => _apiKey.isNotEmpty && _projectId.isNotEmpty && _messagingSenderId.isNotEmpty;

  static bool get isConfigured => _commonConfigured && _appIdForCurrentPlatform.isNotEmpty;

  static String get _appIdForCurrentPlatform {
    if (kIsWeb) return _webAppId;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidAppId;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _iosAppId;
      default:
        return _webAppId;
    }
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _webAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _authDomain.isEmpty ? null : _authDomain,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: _apiKey,
          appId: _androidAppId,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return FirebaseOptions(
          apiKey: _apiKey,
          appId: _iosAppId,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          authDomain: _authDomain.isEmpty ? null : _authDomain,
          storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
          iosClientId: iosClientId.isEmpty ? null : iosClientId,
          iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
        );
      default:
        return FirebaseOptions(
          apiKey: _apiKey,
          appId: _webAppId,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          authDomain: _authDomain.isEmpty ? null : _authDomain,
          storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        );
    }
  }
}

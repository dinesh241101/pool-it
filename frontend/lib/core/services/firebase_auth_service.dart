import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';
import '../constants/app_constants.dart';

/// Thin wrapper around Firebase Auth + Google Sign-In.
///
/// Firebase authenticates the user, then [AuthProvider] exchanges the Firebase
/// ID token with the backend for a Supabase session.
class FirebaseAuthService {
  static bool _initialized = false;
  static Object? _initError;

  /// Android builds get their Firebase config from google-services.json via the
  /// Google Services Gradle plugin, so explicit dart-defines are not required.
  static bool get _usesGoogleServicesConfig => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isConfigured => DefaultFirebaseOptions.isConfigured || _usesGoogleServicesConfig;
  static Object? get initError => _initError;

  static String get _serverClientId {
    if (AppConstants.googleServerClientId.isNotEmpty) return AppConstants.googleServerClientId;
    return DefaultFirebaseOptions.webClientId;
  }

  static String? get _googleClientId {
    if (kIsWeb) {
      return DefaultFirebaseOptions.webClientId.isEmpty ? null : DefaultFirebaseOptions.webClientId;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        final id = DefaultFirebaseOptions.iosClientId.isNotEmpty
            ? DefaultFirebaseOptions.iosClientId
            : AppConstants.googleIosClientId;
        return id.isEmpty ? null : id;
      default:
        return null;
    }
  }

  static Future<void> initialize() async {
    if (_initialized || !isConfigured) return;

    try {
      if (Firebase.apps.isEmpty) {
        if (DefaultFirebaseOptions.isConfigured) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        } else {
          // Android: read the values generated from google-services.json.
          await Firebase.initializeApp();
        }
      }

      if (!kIsWeb) {
        await GoogleSignIn.instance.initialize(
          clientId: _googleClientId,
          serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
        );
      }

      _initError = null;
      _initialized = true;
    } catch (e) {
      // Never block app startup on Firebase: phone OTP must keep working.
      _initError = e;
      debugPrint('Firebase initialization failed: $e');
    }
  }

  /// Returns a fresh Firebase ID token for the signed-in Google user.
  static Future<String?> signInWithGoogle() async {
    if (!isConfigured) {
      throw FirebaseAuthException(
        code: 'firebase-not-configured',
        message: 'Google sign-in is not configured for this build.',
      );
    }

    await initialize();

    if (_initError != null || Firebase.apps.isEmpty) {
      throw FirebaseAuthException(
        code: 'firebase-init-failed',
        message: 'Google sign-in could not start. Please continue with phone OTP.',
      );
    }

    if (kIsWeb) {
      final userCredential = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      return userCredential.user?.getIdToken();
    }

    final googleSignIn = GoogleSignIn.instance;
    if (!googleSignIn.supportsAuthenticate()) {
      throw FirebaseAuthException(
        code: 'google-sign-in-unsupported',
        message: 'Google sign-in is not supported on this platform.',
      );
    }

    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token. Check the OAuth client configuration.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    return userCredential.user?.getIdToken();
  }

  static Future<void> signOut() async {
    if (_initialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
  }
}

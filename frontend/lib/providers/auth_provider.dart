import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../core/services/firebase_auth_service.dart';
import '../core/services/supabase_service.dart';
import '../core/services/cache_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await _syncUser(session.user);
    }
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _syncUser(data.session!.user);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _syncUser(User supabaseUser, {bool forceRefresh = false}) async {
    _currentUser = UserModel(
      id: supabaseUser.id,
      name: supabaseUser.userMetadata?['name'] as String? ?? '',
      phone: (supabaseUser.phone ?? '').replaceAll('+91', ''),
      email: supabaseUser.email ?? '',
      profilePic: supabaseUser.userMetadata?['profile_pic'] as String? ?? '',
      isDriver: supabaseUser.userMetadata?['is_driver'] as bool? ?? false,
      isAdmin: supabaseUser.userMetadata?['is_admin'] as bool? ?? false,
    );

    final cacheKey = 'profile:${supabaseUser.id}';
    final cache = await CacheService.getInstance();

    Map<String, dynamic>? row;
    if (!forceRefresh) {
      final cached = cache.readIfFresh(cacheKey);
      if (cached is Map) row = Map<String, dynamic>.from(cached);
    }

    if (row == null) {
      final profile = await SupabaseService.fetchProfile(supabaseUser.id);
      if (profile != null) {
        row = profile.toJson();
        await cache.put(cacheKey, row);
      }
    }

    if (row != null) {
      _currentUser = _currentUser!.copyWith(
        name: row['name'] as String? ?? _currentUser!.name,
        isDriver: row['isDriver'] as bool? ?? _currentUser!.isDriver,
        isAdmin: row['isAdmin'] as bool? ?? _currentUser!.isAdmin,
      );
    }

    notifyListeners();
  }

  Future<void> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.post('/auth/send-otp', body: {'phone': phone.trim()});
    } catch (e) {
      _error = _messageFrom(e);
      debugPrint('sendOtp error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> dummyLogin() async {
    if (!AppConstants.dummyLoginEnabled) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.post('/auth/send-otp', body: {'phone': AppConstants.dummyPhone});
      final data = await ApiService.post('/auth/verify-otp', body: {'phone': AppConstants.dummyPhone, 'otp': '11111'});
      final tokenHash = data['token_hash'] as String?;
      if (tokenHash == null || tokenHash.isEmpty) {
        _error = 'Login token was missing from server response';
        return false;
      }
      final response = await Supabase.instance.client.auth.verifyOTP(tokenHash: tokenHash, type: OtpType.magiclink);
      if (response.user != null) {
        await _syncUser(response.user!, forceRefresh: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('dummyLogin error: $e');
      _error = _messageFrom(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Google login/signup through Firebase. The backend verifies the Firebase
  /// ID token and returns a Supabase session token so the rest of the app
  /// (RLS, realtime, profiles) continues to work unchanged.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final idToken = await FirebaseAuthService.signInWithGoogle();
      if (idToken == null || idToken.isEmpty) {
        _error = 'Could not get a Google ID token. Please try again.';
        return false;
      }

      final data = await ApiService.post('/auth/firebase', body: {'id_token': idToken});
      final tokenHash = data['token_hash'] as String?;
      if (tokenHash == null || tokenHash.isEmpty) {
        _error = 'Login token was missing from server response';
        return false;
      }

      final response = await Supabase.instance.client.auth.verifyOTP(tokenHash: tokenHash, type: OtpType.magiclink);

      if (response.user != null) {
        await _syncUser(response.user!, forceRefresh: true);
        return true;
      }
      return false;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _error = null;
      } else {
        debugPrint('Google sign-in error: $e');
        _error = _googleMessage(e);
      }
      return false;
    } on FirebaseAuthException catch (e) {
      if (_isWebSignInCancelled(e.code)) {
        _error = null;
      } else {
        debugPrint('Firebase sign-in error: $e');
        _error = _googleMessage(e);
      }
      return false;
    } catch (e) {
      debugPrint('signInWithGoogle error: $e');
      _error = _googleMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.post('/auth/verify-otp', body: {'phone': phone.trim(), 'otp': otp.trim()});

      final tokenHash = data['token_hash'] as String?;
      if (tokenHash == null || tokenHash.isEmpty) {
        _error = 'Login token was missing from server response';
        return false;
      }

      final response = await Supabase.instance.client.auth.verifyOTP(tokenHash: tokenHash, type: OtpType.magiclink);

      if (response.user != null) {
        await _syncUser(response.user!, forceRefresh: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('verifyOtp error: $e');
      _error = _messageFrom(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({String? name, String? email, String? emergencyContact}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final metadata = <String, dynamic>{};
      if (name != null) metadata['name'] = name;
      if (email != null) metadata['email'] = email;
      if (metadata.isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(UserAttributes(data: metadata));
      }

      if (name != null) {
        _currentUser = _currentUser!.copyWith(name: name);
        await SupabaseService.updateProfileName(_currentUser!.id, name);
      }
      if (email != null) {
        _currentUser = _currentUser!.copyWith(email: email);
      }

      final cache = await CacheService.getInstance();
      await cache.remove('profile:${_currentUser!.id}');
      notifyListeners();
    } catch (e) {
      debugPrint('updateProfile error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleDriverMode() async {
    if (_currentUser == null) return;
    final newValue = !_currentUser!.isDriver;
    _currentUser = _currentUser!.copyWith(isDriver: newValue);
    notifyListeners();

    await SupabaseService.updateIsDriver(_currentUser!.id, newValue);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'is_driver': newValue}));
    } catch (_) {}
  }

  Future<void> logout() async {
    await FirebaseAuthService.signOut();
    await Supabase.instance.client.auth.signOut();
    _currentUser = null;
    _error = null;
    final cache = await CacheService.getInstance();
    await cache.clearAll();
    notifyListeners();
  }

  bool _isWebSignInCancelled(String code) {
    return code == 'popup-closed-by-user' ||
        code == 'cancelled-popup-request' ||
        code == 'web-context-canceled';
  }

  String _googleMessage(Object e) {
    if (e is ApiException) return e.message;
    if (e is FirebaseAuthException) {
      if (e.code == 'firebase-not-configured') return 'Google sign-in is not configured for this build.';
      if (e.code == 'firebase-init-failed') {
        return e.message ?? 'Google sign-in could not start. Please continue with phone OTP.';
      }
      if (e.code == 'google-sign-in-unsupported') return 'Google sign-in is not supported on this platform.';
      return e.message ?? 'Google sign-in failed. Please try again.';
    }
    if (e is GoogleSignInException) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          return 'Sign-in cancelled.';
        case GoogleSignInExceptionCode.interrupted:
          return 'Sign-in was interrupted. Please try again.';
        case GoogleSignInExceptionCode.clientConfigurationError:
          return 'Google sign-in is misconfigured. Check the OAuth client settings.';
        default:
          final description = e.description ?? '';
          if (description.contains('serverClientId')) {
            return 'Google sign-in needs the Web OAuth client ID (GOOGLE_WEB_CLIENT_ID).';
          }
          return description.isEmpty ? 'Google sign-in failed. Please try again.' : description;
      }
    }
    return 'Something went wrong. Please try again.';
  }

  String _messageFrom(Object e) {
    final message = e.toString();
    if (message.contains('Invalid OTP')) return 'Invalid OTP. Please try again.';
    if (message.contains('expired')) return 'OTP has expired. Request a new one.';
    if (message.contains('wait')) return 'Please wait a moment before requesting a new OTP.';
    return 'Something went wrong. Please try again.';
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../core/storage/local_storage_service.dart';
import '../core/constants/app_constants.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _generatedOtp;
  String? _pendingPhone;
  final _uuid = const Uuid();

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get pendingPhone => _pendingPhone;

  Future<void> init() async {
    final storage = await LocalStorageService.getInstance();
    final userJson = storage.getString(AppConstants.storageKeyCurrentUser);
    if (userJson != null) {
      _currentUser = UserModel.fromJson(jsonDecode(userJson));
      notifyListeners();
    }
  }

  Future<String> sendOtp(String phone) async {
    _pendingPhone = phone;
    _generatedOtp = (100000 + _uuid.hashCode % 900000).toString();
    debugPrint('OTP for $phone: $_generatedOtp');
    notifyListeners();
    return _generatedOtp!;
  }

  Future<void> loginAsGuest() async {
    _currentUser = UserModel(
      id: _uuid.v4(),
      name: 'Guest',
      phone: '',
      isGuest: true,
    );
    final storage = await LocalStorageService.getInstance();
    await storage.saveString(
        AppConstants.storageKeyCurrentUser, jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }

  Future<bool> verifyOtp(String otp) async {
    if (_generatedOtp == null || _pendingPhone == null) return false;
    if (otp != _generatedOtp) return false;

    final storage = await LocalStorageService.getInstance();
    final usersList = storage.getList(AppConstants.storageKeyUsers);
    final existingUser = usersList.cast<Map<String, dynamic>>().firstWhere(
          (u) => u['phone'] == _pendingPhone,
          orElse: () => <String, dynamic>{},
        );

    if (existingUser.isEmpty) {
      _currentUser = UserModel(
        id: _uuid.v4(),
        name: '',
        phone: _pendingPhone!,
      );
      usersList.add(_currentUser!.toJson());
    } else {
      _currentUser = UserModel.fromJson(existingUser);
    }

    await storage.saveList(AppConstants.storageKeyUsers, usersList);
    await storage.saveString(
        AppConstants.storageKeyCurrentUser, jsonEncode(_currentUser!.toJson()));

    _generatedOtp = null;
    _pendingPhone = null;
    notifyListeners();
    return true;
  }

  Future<void> updateProfile({String? name, String? email, String? emergencyContact}) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      name: name,
      email: email,
      emergencyContact: emergencyContact,
    );
    final storage = await LocalStorageService.getInstance();
    await storage.saveString(
        AppConstants.storageKeyCurrentUser, jsonEncode(_currentUser!.toJson()));

    final usersList = storage.getList(AppConstants.storageKeyUsers);
    final index = usersList.indexWhere(
        (u) => (u as Map<String, dynamic>)['id'] == _currentUser!.id);
    if (index != -1) {
      usersList[index] = _currentUser!.toJson();
      await storage.saveList(AppConstants.storageKeyUsers, usersList);
    }
    notifyListeners();
  }

  Future<void> toggleDriverMode() async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(isDriver: !_currentUser!.isDriver);
    final storage = await LocalStorageService.getInstance();
    await storage.saveString(
        AppConstants.storageKeyCurrentUser, jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    final storage = await LocalStorageService.getInstance();
    await storage.remove(AppConstants.storageKeyCurrentUser);
    _currentUser = null;
    notifyListeners();
  }
}

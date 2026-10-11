import 'package:flutter/material.dart';
import '../core/services/supabase_service.dart';
import '../core/services/cache_service.dart';

class AppConfigProvider extends ChangeNotifier {
  String? _quizUrl;
  bool _isLoading = false;
  String? _error;

  String? get quizUrl => _quizUrl;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<String?> getQuizUrl({bool forceRefresh = false}) async {
    final cache = await CacheService.getInstance();
    const key = 'app_config';

    if (!forceRefresh) {
      final cached = cache.readIfFresh(key);
      if (cached is Map) {
        _quizUrl = cached['quiz_url'] as String? ?? '';
        notifyListeners();
        return _quizUrl;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final row = await SupabaseService.fetchAppConfig();
      if (row != null) {
        _quizUrl = row['quiz_url'] as String? ?? '';
        await cache.put(key, row, ttl: const Duration(minutes: 5));
        _error = null;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('getQuizUrl error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _quizUrl;
  }

  Future<bool> updateQuizUrl(String url) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trimmed = url.trim();
      final result = await SupabaseService.updateAppConfig(trimmed);
      _quizUrl = result['quiz_url'] as String? ?? trimmed;
      final cache = await CacheService.getInstance();
      await cache.remove('app_config');
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('updateQuizUrl error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

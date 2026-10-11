import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class _CacheEntry {
  final dynamic data;
  final DateTime storedAt;
  final Duration ttl;

  const _CacheEntry(this.data, this.storedAt, this.ttl);
}

/// Keyed, in-memory + SharedPreferences backed cache.
///
/// Every read is served from memory for the current session and from
/// SharedPreferences after a restart, as long as the entry is still within
/// its TTL. The data layer therefore only hits the backend when an entry is
/// missing or expired - "fetch once until new/updated results are available".
class CacheService {
  static CacheService? _instance;
  SharedPreferences? _prefs;
  final Map<String, _CacheEntry> _memory = {};

  SharedPreferences get _p => _prefs!;

  CacheService._();

  static Future<CacheService> getInstance() async {
    final instance = _instance ??= CacheService._();
    instance._prefs ??= await SharedPreferences.getInstance();
    return instance;
  }

  Future<void> put(String key, dynamic data, {Duration ttl = const Duration(minutes: 5)}) async {
    final entry = _CacheEntry(data, DateTime.now(), ttl);
    _memory[key] = entry;
    await _p.setString(
      'poolit_cache_$key',
      jsonEncode({'data': data, 'storedAt': entry.storedAt.toIso8601String(), 'ttlMs': ttl.inMilliseconds}),
    );
  }

  /// Returns the cached value only if it is still fresh (not expired).
  dynamic readIfFresh(String key) {
    final entry = _read(key);
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) > entry.ttl) return null;
    return entry.data;
  }

  /// Returns the cached value even if expired, or null when never cached.
  dynamic readStale(String key) {
    return _read(key)?.data;
  }

  bool isFresh(String key) {
    final entry = _read(key);
    if (entry == null) return false;
    return DateTime.now().difference(entry.storedAt) <= entry.ttl;
  }

  Future<void> remove(String key) async {
    _memory.remove(key);
    await _p.remove('poolit_cache_$key');
  }

  Future<void> removePrefix(String prefix) async {
    final keysToRemove = _memory.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      await remove(key);
    }
  }

  Future<void> clearAll() async {
    _memory.clear();
    final keys = _p.getKeys().where((k) => k.startsWith('poolit_cache_')).toList();
    for (final key in keys) {
      await _p.remove(key);
    }
  }

  _CacheEntry? _read(String key) {
    final mem = _memory[key];
    if (mem != null) return mem;

    final raw = _p.getString('poolit_cache_$key');
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entry = _CacheEntry(
        decoded['data'],
        DateTime.parse(decoded['storedAt'] as String),
        Duration(milliseconds: (decoded['ttlMs'] as num).toInt()),
      );
      _memory[key] = entry;
      return entry;
    } catch (_) {
      return null;
    }
  }
}

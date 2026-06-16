import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ApiCacheService {
  static const _cacheFileName = 'api_cache.json';
  static const _cacheDuration = Duration(days: 7); // Cache for 7 days

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  Future<Map<String, dynamic>> _loadCache() async {
    try {
      final f = await _cacheFile();
      if (!await f.exists()) return {};
      final raw = await f.readAsString();
      final jsonMap = jsonDecode(raw);
      if (jsonMap is Map<String, dynamic>) {
        return jsonMap;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCache(Map<String, dynamic> cache) async {
    final f = await _cacheFile();
    await f.writeAsString(jsonEncode(cache));
  }

  /// Get cached result for a given key
  /// Returns null if not found or expired
  Future<String?> getResultFromCache(String key) async {
    final cache = await _loadCache();
    
    if (!cache.containsKey(key)) {
      return null;
    }

    final cachedItem = cache[key];
    if (cachedItem is! Map<String, dynamic>) {
      return null;
    }

    // Check if cache is expired
    final cachedAt = DateTime.parse(cachedItem['cachedAt']);
    if (DateTime.now().difference(cachedAt) > _cacheDuration) {
      // Remove expired entry
      cache.remove(key);
      await _saveCache(cache);
      return null;
    }

    return cachedItem['data'];
  }

  /// Save result to cache with a given key
  Future<void> saveResultToCache(String key, String jsonData) async {
    final cache = await _loadCache();
    
    cache[key] = {
      'data': jsonData,
      'cachedAt': DateTime.now().toIso8601String(),
    };

    await _saveCache(cache);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    final f = await _cacheFile();
    if (await f.exists()) {
      await f.delete();
    }
  }

  /// Clear specific cache entry
  Future<void> clearCacheEntry(String key) async {
    final cache = await _loadCache();
    if (cache.containsKey(key)) {
      cache.remove(key);
      await _saveCache(cache);
    }
  }
}

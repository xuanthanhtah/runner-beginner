import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/workout_config.dart';

abstract interface class SettingsRepository {
  WorkoutConfig load();
  Future<void> save(WorkoutConfig config);
}

class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs);

  static const key = 'workout_config';
  static const cacheOptions =
      SharedPreferencesWithCacheOptions(allowList: {key});

  final SharedPreferencesWithCache _prefs;

  @override
  WorkoutConfig load() {
    final raw = _prefs.getString(key);
    if (raw == null) return WorkoutConfig.defaults;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, Object?>) return WorkoutConfig.fromJson(json);
    } on FormatException catch (e) {
      debugPrint('SettingsRepository: corrupt settings, using defaults: $e');
    }
    return WorkoutConfig.defaults;
  }

  @override
  Future<void> save(WorkoutConfig config) =>
      _prefs.setString(key, jsonEncode(config.toJson()));
}

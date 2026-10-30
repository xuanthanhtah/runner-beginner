import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'application/providers.dart';
import 'services/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: SharedPrefsSettingsRepository.cacheOptions,
  );

  runApp(ProviderScope(
    overrides: [
      settingsRepositoryProvider
          .overrideWithValue(SharedPrefsSettingsRepository(prefs)),
    ],
    child: const RunWalkApp(),
  ));
}

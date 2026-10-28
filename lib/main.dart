import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/providers.dart';
import 'data/storage/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SharedPreferencesStore();
  final initialData = await InitialData.load(store);
  runApp(
    ProviderScope(
      // Platform calls are local; retrying failures only hides real problems.
      retry: (_, _) => null,
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        initialDataProvider.overrideWithValue(initialData),
      ],
      child: const OpenBlockApp(),
    ),
  );
}

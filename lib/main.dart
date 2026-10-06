import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/app_version_provider.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    ProviderScope(
      overrides: [appVersionProvider.overrideWithValue(packageInfo.version)],
      child: const OphirApp(),
    ),
  );
}

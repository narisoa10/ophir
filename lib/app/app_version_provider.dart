import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app version name (`version` in pubspec.yaml), read from the platform
/// once at startup and injected with `overrideWithValue` in `main`.
final appVersionProvider = Provider<String>((ref) {
  throw UnimplementedError('appVersionProvider must be overridden in main.');
});

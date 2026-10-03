import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';

/// Applies a re-read [Result] without discarding the last successful value.
///
/// A [Failure] never replaces a loaded [Success]; without one it is applied
/// exactly as a fresh build would apply it.
mixin LastGoodResultNotifier<T> on AsyncNotifier<Result<T>> {
  void applyRefreshedResult(Result<T> result) {
    if (result is Failure<T> && state.value is Success<T>) {
      return;
    }

    state = AsyncData(result);
  }
}

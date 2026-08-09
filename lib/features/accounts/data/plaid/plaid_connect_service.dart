import 'dart:async';

import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';

sealed class PlaidConnectOutcome {
  const PlaidConnectOutcome();
}

final class PlaidConnectCompleted extends PlaidConnectOutcome {
  const PlaidConnectCompleted(this.connectionId);

  final String connectionId;
}

final class PlaidConnectCancelled extends PlaidConnectOutcome {
  const PlaidConnectCancelled();
}

final class PlaidConnectFailed extends PlaidConnectOutcome {
  const PlaidConnectFailed(this.failure);

  final AppFailure failure;
}

final class PlaidConnectService {
  const PlaidConnectService(this._client);

  final SupabaseClient _client;

  Future<PlaidConnectOutcome> connect({required String locale}) async {
    final linkTokenResult = await _createLinkToken(locale);
    if (linkTokenResult is Failure<String>) {
      return PlaidConnectFailed(linkTokenResult.failure);
    }

    final linkToken = (linkTokenResult as Success<String>).value;
    final publicTokenResult = await _openLink(linkToken);
    if (publicTokenResult is Failure<String>) {
      final failure = publicTokenResult.failure;
      if (failure is ValidationFailure) {
        return const PlaidConnectCancelled();
      }
      return PlaidConnectFailed(failure);
    }

    final publicToken = (publicTokenResult as Success<String>).value;
    final exchangeResult = await _exchangePublicToken(publicToken);
    if (exchangeResult is Failure<String>) {
      return PlaidConnectFailed(exchangeResult.failure);
    }

    return PlaidConnectCompleted((exchangeResult as Success<String>).value);
  }

  Future<Result<String>> _createLinkToken(String locale) async {
    try {
      final response = await _client.functions.invoke(
        'plaid-create-link-token',
        body: {'locale': locale},
      );

      final failure = _failureFromResponseStatus(response.status);
      if (failure != null) {
        return Failure(failure);
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const Failure(UnknownFailure());
      }

      final linkToken = data['link_token'];
      if (linkToken is! String || linkToken.isEmpty) {
        return const Failure(UnknownFailure());
      }

      return Success(linkToken);
    } on FunctionException catch (exception) {
      return Failure(_failureFromFunctionException(exception));
    } catch (_) {
      return const Failure(NetworkFailure());
    }
  }

  Future<Result<String>> _exchangePublicToken(String publicToken) async {
    try {
      final response = await _client.functions.invoke(
        'plaid-exchange-public-token',
        body: {'public_token': publicToken},
      );

      final failure = _failureFromResponseStatus(response.status);
      if (failure != null) {
        return Failure(failure);
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const Failure(UnknownFailure());
      }

      final connectionId = data['connection_id'];
      if (connectionId is! String || connectionId.isEmpty) {
        return const Failure(UnknownFailure());
      }

      return Success(connectionId);
    } on FunctionException catch (exception) {
      return Failure(_failureFromFunctionException(exception));
    } catch (_) {
      return const Failure(NetworkFailure());
    }
  }

  Future<Result<String>> _openLink(String linkToken) async {
    StreamSubscription<LinkSuccess>? successSubscription;
    StreamSubscription<LinkExit>? exitSubscription;
    final completer = Completer<Result<String>>();

    successSubscription = PlaidLink.onSuccess.listen((success) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(Success(success.publicToken));
    });

    exitSubscription = PlaidLink.onExit.listen((exit) {
      if (completer.isCompleted) {
        return;
      }
      if (exit.error != null) {
        completer.complete(const Failure(UnknownFailure()));
        return;
      }
      completer.complete(const Failure(ValidationFailure()));
    });

    try {
      await PlaidLink.create(
        configuration: LinkTokenConfiguration(token: linkToken),
      );
      await PlaidLink.open();
      return await completer.future;
    } catch (_) {
      if (!completer.isCompleted) {
        return const Failure(UnknownFailure());
      }
      return const Failure(UnknownFailure());
    } finally {
      await successSubscription.cancel();
      await exitSubscription.cancel();
      await PlaidLink.close();
    }
  }

  AppFailure? _failureFromResponseStatus(int status) {
    if (status == 200) {
      return null;
    }
    if (status == 401) {
      return const UnauthorizedFailure();
    }
    if (status >= 500) {
      return const UnknownFailure();
    }
    return const UnknownFailure();
  }

  AppFailure _failureFromFunctionException(FunctionException exception) {
    final status = exception.status;
    if (status == 401) {
      return const UnauthorizedFailure();
    }
    if (status == 400) {
      return const ValidationFailure();
    }
    return const UnknownFailure();
  }
}

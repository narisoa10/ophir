import 'dart:async';

import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/plaid_connection_health.dart';
import '../dto/plaid_connection_health_dto.dart';
import 'plaid_edge_failure.dart';

typedef PlaidFunctionInvoker =
    Future<FunctionResponse> Function(
      String functionName, {
      required Map<String, dynamic> body,
    });

typedef PlaidLinkLauncher =
    Future<PlaidLinkSessionResult> Function(String linkToken);

sealed class PlaidLinkSessionResult {
  const PlaidLinkSessionResult();
}

final class PlaidLinkSessionSucceeded extends PlaidLinkSessionResult {
  const PlaidLinkSessionSucceeded(this.success);

  final LinkSuccess success;
}

/// The user closed Link without an error.
final class PlaidLinkSessionExited extends PlaidLinkSessionResult {
  const PlaidLinkSessionExited();
}

final class PlaidLinkSessionFailed extends PlaidLinkSessionResult {
  const PlaidLinkSessionFailed();
}

sealed class PlaidReconnectOutcome {
  const PlaidReconnectOutcome();
}

/// Link update mode succeeded and the server re-checked the Item.
final class PlaidReconnectConfirmed extends PlaidReconnectOutcome {
  const PlaidReconnectConfirmed(this.refresh);

  final PlaidItemStatusRefresh refresh;
}

final class PlaidReconnectCancelled extends PlaidReconnectOutcome {
  const PlaidReconnectCancelled();
}

final class PlaidReconnectFailed extends PlaidReconnectOutcome {
  const PlaidReconnectFailed(this.failure);

  final AppFailure failure;
}

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

final class PlaidConnectDuplicate extends PlaidConnectOutcome {
  const PlaidConnectDuplicate();
}

final class PlaidConnectFailed extends PlaidConnectOutcome {
  const PlaidConnectFailed(this.failure);

  final AppFailure failure;
}

final class PlaidConnectService {
  PlaidConnectService(SupabaseClient client)
    : this.withDependencies(
        invokeFunction: (functionName, {required body}) =>
            client.functions.invoke(functionName, body: body),
        launchLink: launchPlaidLink,
      );

  const PlaidConnectService.withDependencies({
    required PlaidFunctionInvoker invokeFunction,
    required PlaidLinkLauncher launchLink,
  }) : _invokeFunction = invokeFunction,
       _launchLink = launchLink;

  final PlaidFunctionInvoker _invokeFunction;
  final PlaidLinkLauncher _launchLink;

  Future<PlaidConnectOutcome> connect({required String locale}) async {
    final linkTokenResult = await _createLinkToken(locale);
    if (linkTokenResult is Failure<String>) {
      return PlaidConnectFailed(linkTokenResult.failure);
    }

    final linkToken = (linkTokenResult as Success<String>).value;
    final linkSuccessResult = await _openLink(linkToken);
    if (linkSuccessResult is Failure<PlaidLinkSuccessPayload>) {
      final failure = linkSuccessResult.failure;
      if (failure is ValidationFailure) {
        return const PlaidConnectCancelled();
      }
      return PlaidConnectFailed(failure);
    }

    final linkSuccess =
        (linkSuccessResult as Success<PlaidLinkSuccessPayload>).value;
    final exchangeResult = await _exchangePublicToken(linkSuccess);
    if (exchangeResult is Failure<PlaidExchangeResult>) {
      return PlaidConnectFailed(exchangeResult.failure);
    }

    final exchange = (exchangeResult as Success<PlaidExchangeResult>).value;
    return switch (exchange) {
      PlaidExchangeCompleted(:final connectionId) => PlaidConnectCompleted(
        connectionId,
      ),
      PlaidExchangeDuplicate() => const PlaidConnectDuplicate(),
    };
  }

  /// Repairs an existing Item through Link update mode. The public token from
  /// update mode is never exchanged: the Item and its access token stay the
  /// same, and only the server's `/item/get` check decides the new health.
  Future<PlaidReconnectOutcome> reconnect({
    required String connectionId,
    required String locale,
  }) async {
    final linkTokenResult = await _createUpdateLinkToken(
      connectionId: connectionId,
      locale: locale,
    );
    if (linkTokenResult is Failure<String>) {
      return PlaidReconnectFailed(linkTokenResult.failure);
    }

    final linkToken = (linkTokenResult as Success<String>).value;
    final PlaidLinkSessionResult session;
    try {
      session = await _launchLink(linkToken);
    } catch (_) {
      return const PlaidReconnectFailed(UnknownFailure());
    }

    switch (session) {
      case PlaidLinkSessionExited():
        return const PlaidReconnectCancelled();
      case PlaidLinkSessionFailed():
        return const PlaidReconnectFailed(UnknownFailure());
      case PlaidLinkSessionSucceeded():
        break;
    }

    final refreshResult = await refreshItemStatus(connectionId);
    return switch (refreshResult) {
      Success<PlaidItemStatusRefresh>(:final value) => PlaidReconnectConfirmed(
        value,
      ),
      Failure<PlaidItemStatusRefresh>(:final failure) => PlaidReconnectFailed(
        failure,
      ),
    };
  }

  Future<Result<PlaidItemStatusRefresh>> refreshItemStatus(
    String connectionId,
  ) async {
    try {
      final response = await _invokeFunction(
        'plaid-refresh-item-status',
        body: {'connection_id': connectionId},
      );

      final failure = _failureFromResponseStatus(response.status);
      if (failure != null) {
        return Failure(failure);
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const Failure(UnknownFailure());
      }

      final status = parsePlaidConnectionStatus(data['status']);
      if (status == null) {
        return const Failure(UnknownFailure());
      }

      return Success(
        PlaidItemStatusRefresh(
          status: status,
          statusReason: parsePlaidConnectionStatusReason(data['status_reason']),
        ),
      );
    } on FunctionException catch (exception) {
      return Failure(plaidFailureFromFunctionException(exception));
    } catch (_) {
      return const Failure(NetworkFailure());
    }
  }

  Future<Result<String>> _createUpdateLinkToken({
    required String connectionId,
    required String locale,
  }) async {
    try {
      final response = await _invokeFunction(
        'plaid-create-link-token',
        body: {'locale': locale, 'connection_id': connectionId},
      );

      final failure = _failureFromResponseStatus(response.status);
      if (failure != null) {
        return Failure(failure);
      }

      final data = response.data;
      if (data is! Map<String, dynamic> || data['mode'] != 'update') {
        return const Failure(UnknownFailure());
      }

      final linkToken = data['link_token'];
      if (linkToken is! String || linkToken.isEmpty) {
        return const Failure(UnknownFailure());
      }

      return Success(linkToken);
    } on FunctionException catch (exception) {
      return Failure(plaidFailureFromFunctionException(exception));
    } catch (_) {
      return const Failure(NetworkFailure());
    }
  }

  Future<Result<String>> _createLinkToken(String locale) async {
    try {
      final response = await _invokeFunction(
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

  Future<Result<PlaidExchangeResult>> _exchangePublicToken(
    PlaidLinkSuccessPayload payload,
  ) async {
    try {
      final response = await _invokeFunction(
        'plaid-exchange-public-token',
        body: payload.toJson(),
      );

      final failure = _failureFromResponseStatus(response.status);
      if (failure != null) {
        return Failure(failure);
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const Failure(UnknownFailure());
      }

      if (data['status'] == 'duplicate') {
        return const Success(PlaidExchangeDuplicate());
      }

      final connectionId = data['connection_id'];
      if (connectionId is! String || connectionId.isEmpty) {
        return const Failure(UnknownFailure());
      }

      return Success(PlaidExchangeCompleted(connectionId));
    } on FunctionException catch (exception) {
      return Failure(_failureFromFunctionException(exception));
    } catch (_) {
      return const Failure(NetworkFailure());
    }
  }

  Future<Result<PlaidLinkSuccessPayload>> _openLink(String linkToken) async {
    final PlaidLinkSessionResult session;
    try {
      session = await _launchLink(linkToken);
    } catch (_) {
      return const Failure(UnknownFailure());
    }

    return switch (session) {
      PlaidLinkSessionSucceeded(:final success) => _payloadFromLinkSuccess(
        success,
      ),
      PlaidLinkSessionExited() => const Failure(ValidationFailure()),
      PlaidLinkSessionFailed() => const Failure(UnknownFailure()),
    };
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

  Result<PlaidLinkSuccessPayload> _payloadFromLinkSuccess(LinkSuccess success) {
    final publicToken = success.publicToken;
    if (publicToken.isEmpty) {
      return const Failure(UnknownFailure());
    }

    final institutionId = success.metadata.institution?.id.trim();
    if (institutionId == null || institutionId.isEmpty) {
      return const Failure(ValidationFailure());
    }

    final selectedAccounts = <PlaidSelectedAccountMetadata>[];
    for (final account in success.metadata.accounts) {
      final name = account.name.trim();
      final mask = account.mask?.trim();

      if (name.isEmpty || mask == null || mask.isEmpty) {
        return const Failure(ValidationFailure());
      }

      selectedAccounts.add(
        PlaidSelectedAccountMetadata(name: name, mask: mask),
      );
    }

    if (selectedAccounts.isEmpty) {
      return const Failure(ValidationFailure());
    }

    return Success(
      PlaidLinkSuccessPayload(
        publicToken: publicToken,
        institutionId: institutionId,
        selectedAccounts: selectedAccounts,
      ),
    );
  }
}

Future<PlaidLinkSessionResult> launchPlaidLink(String linkToken) async {
  StreamSubscription<LinkSuccess>? successSubscription;
  StreamSubscription<LinkExit>? exitSubscription;
  final completer = Completer<PlaidLinkSessionResult>();

  successSubscription = PlaidLink.onSuccess.listen((success) {
    if (completer.isCompleted) {
      return;
    }
    completer.complete(PlaidLinkSessionSucceeded(success));
  });

  exitSubscription = PlaidLink.onExit.listen((exit) {
    if (completer.isCompleted) {
      return;
    }
    completer.complete(
      exit.error != null
          ? const PlaidLinkSessionFailed()
          : const PlaidLinkSessionExited(),
    );
  });

  try {
    await PlaidLink.create(
      configuration: LinkTokenConfiguration(token: linkToken),
    );
    await PlaidLink.open();
    return await completer.future;
  } catch (_) {
    return const PlaidLinkSessionFailed();
  } finally {
    await successSubscription.cancel();
    await exitSubscription.cancel();
    await PlaidLink.close();
  }
}

final class PlaidLinkSuccessPayload {
  const PlaidLinkSuccessPayload({
    required this.publicToken,
    required this.institutionId,
    required this.selectedAccounts,
  });

  final String publicToken;
  final String institutionId;
  final List<PlaidSelectedAccountMetadata> selectedAccounts;

  Map<String, dynamic> toJson() {
    return {
      'public_token': publicToken,
      'institution_id': institutionId,
      'selected_accounts': selectedAccounts
          .map((account) => account.toJson())
          .toList(growable: false),
    };
  }
}

final class PlaidSelectedAccountMetadata {
  const PlaidSelectedAccountMetadata({required this.name, required this.mask});

  final String name;
  final String mask;

  Map<String, dynamic> toJson() {
    return {'name': name, 'mask': mask};
  }
}

sealed class PlaidExchangeResult {
  const PlaidExchangeResult();
}

final class PlaidExchangeCompleted extends PlaidExchangeResult {
  const PlaidExchangeCompleted(this.connectionId);

  final String connectionId;
}

final class PlaidExchangeDuplicate extends PlaidExchangeResult {
  const PlaidExchangeDuplicate();
}

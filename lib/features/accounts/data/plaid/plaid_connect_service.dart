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

final class PlaidConnectDuplicate extends PlaidConnectOutcome {
  const PlaidConnectDuplicate();
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

  Future<Result<PlaidExchangeResult>> _exchangePublicToken(
    PlaidLinkSuccessPayload payload,
  ) async {
    try {
      final response = await _client.functions.invoke(
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
    StreamSubscription<LinkSuccess>? successSubscription;
    StreamSubscription<LinkExit>? exitSubscription;
    final completer = Completer<Result<PlaidLinkSuccessPayload>>();

    successSubscription = PlaidLink.onSuccess.listen((success) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(_payloadFromLinkSuccess(success));
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

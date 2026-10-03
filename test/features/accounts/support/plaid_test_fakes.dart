import 'dart:async';

import 'package:ophir/features/accounts/data/plaid/plaid_connect_service.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class RecordedFunctionCall {
  const RecordedFunctionCall(this.functionName, this.body);

  final String functionName;
  final Map<String, dynamic> body;
}

typedef FakeFunctionHandler =
    FutureOr<FunctionResponse> Function(Map<String, dynamic> body);

/// Fake Edge Function transport. Unknown functions fail the test loudly.
final class FakePlaidFunctions {
  FakePlaidFunctions(this.handlers);

  final Map<String, FakeFunctionHandler> handlers;
  final List<RecordedFunctionCall> calls = <RecordedFunctionCall>[];

  List<String> get functionNames =>
      calls.map((call) => call.functionName).toList(growable: false);

  Future<FunctionResponse> invoke(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    calls.add(RecordedFunctionCall(functionName, body));
    final handler = handlers[functionName];
    if (handler == null) {
      throw StateError('Unexpected Edge Function call: $functionName');
    }
    return handler(body);
  }
}

FunctionResponse okResponse(Map<String, dynamic> data) {
  return FunctionResponse(data: data, status: 200);
}

FunctionException edgeError(int status, String code) {
  return FunctionException(
    status: status,
    details: {
      'error': {'code': code},
    },
  );
}

final class FakePlaidLink {
  FakePlaidLink({PlaidLinkSessionResult? result})
    : result = result ?? PlaidLinkSessionSucceeded(linkSuccess());

  PlaidLinkSessionResult result;
  Completer<PlaidLinkSessionResult>? pending;
  final List<String> openedTokens = <String>[];

  Future<PlaidLinkSessionResult> launch(String linkToken) {
    openedTokens.add(linkToken);
    final waiting = pending;
    if (waiting != null) {
      return waiting.future;
    }
    return Future.value(result);
  }
}

LinkSuccess linkSuccess({List<LinkAccount>? accounts}) {
  return LinkSuccess(
    publicToken: 'public-sandbox-token',
    metadata: LinkSuccessMetadata(
      linkSessionId: 'link-session',
      institution: LinkInstitution(id: 'ins_1', name: 'Test Bank'),
      accounts:
          accounts ??
          [
            LinkAccount(
              id: 'plaid-account-1',
              mask: '0000',
              name: 'Checking',
              type: 'depository',
              subtype: 'checking',
              verificationStatus: null,
            ),
          ],
    ),
  );
}

PlaidConnectService fakeConnectService(
  FakePlaidFunctions functions,
  FakePlaidLink link,
) {
  return PlaidConnectService.withDependencies(
    invokeFunction: functions.invoke,
    launchLink: link.launch,
  );
}

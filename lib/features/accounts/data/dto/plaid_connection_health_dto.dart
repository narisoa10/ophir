import '../../domain/entities/plaid_connection_health.dart';

PlaidConnectionStatus? parsePlaidConnectionStatus(Object? value) {
  return switch (value) {
    'active' => PlaidConnectionStatus.active,
    'login_required' => PlaidConnectionStatus.loginRequired,
    _ => null,
  };
}

PlaidConnectionStatusReason? parsePlaidConnectionStatusReason(Object? value) {
  return switch (value) {
    null => null,
    'login_required' => PlaidConnectionStatusReason.loginRequired,
    'consent_expired' => PlaidConnectionStatusReason.consentExpired,
    'permission_revoked' => PlaidConnectionStatusReason.permissionRevoked,
    _ => PlaidConnectionStatusReason.unknown,
  };
}

DateTime? _parseOptionalTimestamp(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}

/// Maps one `plaid_list_connection_health()` row. Rows without a usable
/// connection id or with a status this client does not know are skipped, so a
/// future server status never produces a misleading warning.
PlaidConnectionHealth? plaidConnectionHealthFromJson(Map<String, dynamic> json) {
  final connectionId = json['connection_id'];
  final status = parsePlaidConnectionStatus(json['status']);
  if (connectionId is! String || connectionId.trim().isEmpty || status == null) {
    return null;
  }

  return PlaidConnectionHealth(
    connectionId: connectionId.trim(),
    status: status,
    statusReason: parsePlaidConnectionStatusReason(json['status_reason']),
    statusChangedAt: _parseOptionalTimestamp(json['status_changed_at']),
    consentExpiresAt: _parseOptionalTimestamp(json['consent_expires_at']),
    pendingDisconnectAt: _parseOptionalTimestamp(json['pending_disconnect_at']),
    disconnectedAt: _parseOptionalTimestamp(json['disconnected_at']),
  );
}

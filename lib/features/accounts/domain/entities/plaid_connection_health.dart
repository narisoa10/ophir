enum PlaidConnectionStatus { active, loginRequired }

enum PlaidConnectionStatusReason {
  loginRequired,
  consentExpired,
  permissionRevoked,
  unknown,
}

final class PlaidConnectionHealth {
  const PlaidConnectionHealth({
    required this.connectionId,
    required this.status,
    this.statusReason,
    this.statusChangedAt,
    this.consentExpiresAt,
    this.pendingDisconnectAt,
  });

  final String connectionId;
  final PlaidConnectionStatus status;
  final PlaidConnectionStatusReason? statusReason;
  final DateTime? statusChangedAt;
  final DateTime? consentExpiresAt;
  final DateTime? pendingDisconnectAt;

  bool get requiresReconnect => status == PlaidConnectionStatus.loginRequired;

  /// Plaid announced a pending disconnect for an Item that is still healthy;
  /// update mode extends access. [consentExpiresAt] alone never asks for it.
  bool get requiresAccessExtension =>
      status == PlaidConnectionStatus.active && pendingDisconnectAt != null;
}

/// Server-confirmed health returned by `plaid-refresh-item-status`.
final class PlaidItemStatusRefresh {
  const PlaidItemStatusRefresh({required this.status, this.statusReason});

  final PlaidConnectionStatus status;
  final PlaidConnectionStatusReason? statusReason;
}

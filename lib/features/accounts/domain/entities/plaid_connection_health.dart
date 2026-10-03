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
    this.disconnectedAt,
  });

  final String connectionId;
  final PlaidConnectionStatus status;
  final PlaidConnectionStatusReason? statusReason;
  final DateTime? statusChangedAt;
  final DateTime? consentExpiresAt;
  final DateTime? pendingDisconnectAt;
  final DateTime? disconnectedAt;

  /// The user disconnected this Item: the Plaid Item and its access token are
  /// gone, so the remaining status fields describe a link that no longer exists.
  bool get isDisconnected => disconnectedAt != null;

  bool get requiresReconnect =>
      !isDisconnected && status == PlaidConnectionStatus.loginRequired;

  /// Plaid announced a pending disconnect for an Item that is still healthy;
  /// update mode extends access. [consentExpiresAt] alone never asks for it.
  bool get requiresAccessExtension =>
      !isDisconnected &&
      status == PlaidConnectionStatus.active &&
      pendingDisconnectAt != null;
}

/// Server-confirmed health returned by `plaid-refresh-item-status`.
final class PlaidItemStatusRefresh {
  const PlaidItemStatusRefresh({required this.status, this.statusReason});

  final PlaidConnectionStatus status;
  final PlaidConnectionStatusReason? statusReason;
}

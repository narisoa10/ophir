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

  /// The nearest Plaid access deadline that is still ahead of [now].
  DateTime? upcomingAccessDeadline(DateTime now) {
    DateTime? nearest;
    for (final deadline in [consentExpiresAt, pendingDisconnectAt]) {
      if (deadline == null || !deadline.isAfter(now)) {
        continue;
      }
      if (nearest == null || deadline.isBefore(nearest)) {
        nearest = deadline;
      }
    }
    return nearest;
  }
}

/// Server-confirmed health returned by `plaid-refresh-item-status`.
final class PlaidItemStatusRefresh {
  const PlaidItemStatusRefresh({required this.status, this.statusReason});

  final PlaidConnectionStatus status;
  final PlaidConnectionStatusReason? statusReason;
}

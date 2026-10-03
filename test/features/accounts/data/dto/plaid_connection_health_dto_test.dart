import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/accounts/data/dto/plaid_connection_health_dto.dart';
import 'package:ophir/features/accounts/domain/entities/plaid_connection_health.dart';

Map<String, dynamic> _row({
  Object? connectionId = 'item-1',
  Object? status = 'active',
  Object? statusReason,
  Object? statusChangedAt,
  Object? consentExpiresAt,
  Object? pendingDisconnectAt,
  Object? disconnectedAt,
}) {
  return {
    'connection_id': connectionId,
    'status': status,
    'status_reason': statusReason,
    'status_changed_at': statusChangedAt,
    'consent_expires_at': consentExpiresAt,
    'pending_disconnect_at': pendingDisconnectAt,
    'disconnected_at': disconnectedAt,
  };
}

void main() {
  group('plaidConnectionHealthFromJson', () {
    test('parses active connection', () {
      final health = plaidConnectionHealthFromJson(_row())!;

      expect(health.connectionId, 'item-1');
      expect(health.status, PlaidConnectionStatus.active);
      expect(health.statusReason, isNull);
      expect(health.requiresReconnect, isFalse);
    });

    test('parses login_required with known reasons', () {
      const reasons = {
        'login_required': PlaidConnectionStatusReason.loginRequired,
        'consent_expired': PlaidConnectionStatusReason.consentExpired,
        'permission_revoked': PlaidConnectionStatusReason.permissionRevoked,
      };

      for (final entry in reasons.entries) {
        final health = plaidConnectionHealthFromJson(
          _row(status: 'login_required', statusReason: entry.key),
        )!;

        expect(health.status, PlaidConnectionStatus.loginRequired);
        expect(health.statusReason, entry.value);
        expect(health.requiresReconnect, isTrue);
      }
    });

    test('unknown future reason maps to unknown without crashing', () {
      final health = plaidConnectionHealthFromJson(
        _row(status: 'login_required', statusReason: 'future_reason'),
      )!;

      expect(health.status, PlaidConnectionStatus.loginRequired);
      expect(health.statusReason, PlaidConnectionStatusReason.unknown);
    });

    test('unknown future status is skipped instead of guessed', () {
      expect(
        plaidConnectionHealthFromJson(_row(status: 'future_status')),
        isNull,
      );
      expect(plaidConnectionHealthFromJson(_row(status: null)), isNull);
    });

    test('missing or blank connection id is skipped', () {
      expect(plaidConnectionHealthFromJson(_row(connectionId: null)), isNull);
      expect(plaidConnectionHealthFromJson(_row(connectionId: ' ')), isNull);
      expect(plaidConnectionHealthFromJson(_row(connectionId: 42)), isNull);
    });

    test('parses timestamps', () {
      final health = plaidConnectionHealthFromJson(
        _row(
          statusChangedAt: '2026-10-01T10:00:00+00:00',
          consentExpiresAt: '2026-12-01T00:00:00Z',
          pendingDisconnectAt: '2026-11-15T00:00:00Z',
        ),
      )!;

      expect(health.statusChangedAt, DateTime.utc(2026, 10, 1, 10));
      expect(health.consentExpiresAt, DateTime.utc(2026, 12, 1));
      expect(health.pendingDisconnectAt, DateTime.utc(2026, 11, 15));
    });

    test('malformed optional timestamps become null', () {
      final health = plaidConnectionHealthFromJson(
        _row(
          statusChangedAt: 'not-a-date',
          consentExpiresAt: 12345,
          pendingDisconnectAt: '',
        ),
      )!;

      expect(health.statusChangedAt, isNull);
      expect(health.consentExpiresAt, isNull);
      expect(health.pendingDisconnectAt, isNull);
    });

    test('parses disconnected_at', () {
      final health = plaidConnectionHealthFromJson(
        _row(disconnectedAt: '2026-10-03T21:30:00+00:00'),
      )!;

      expect(health.disconnectedAt, DateTime.utc(2026, 10, 3, 21, 30));
      expect(health.isDisconnected, isTrue);
    });

    test('missing disconnected_at means connected', () {
      final health = plaidConnectionHealthFromJson(_row())!;

      expect(health.disconnectedAt, isNull);
      expect(health.isDisconnected, isFalse);
    });

    test('malformed disconnected_at becomes null', () {
      for (final value in <Object>['not-a-date', '', 12345, true]) {
        final health = plaidConnectionHealthFromJson(
          _row(disconnectedAt: value),
        )!;

        expect(health.disconnectedAt, isNull);
        expect(health.isDisconnected, isFalse);
      }
    });

    test('disconnected keeps the stale status fields it was read with', () {
      final health = plaidConnectionHealthFromJson(
        _row(
          status: 'login_required',
          statusReason: 'login_required',
          pendingDisconnectAt: '2026-11-15T00:00:00Z',
          disconnectedAt: '2026-10-03T00:00:00Z',
        ),
      )!;

      expect(health.status, PlaidConnectionStatus.loginRequired);
      expect(health.pendingDisconnectAt, DateTime.utc(2026, 11, 15));
      expect(health.isDisconnected, isTrue);
    });
  });

  group('disconnected priority', () {
    test('disconnected suppresses reconnect', () {
      final health = PlaidConnectionHealth(
        connectionId: 'item-1',
        status: PlaidConnectionStatus.loginRequired,
        statusReason: PlaidConnectionStatusReason.loginRequired,
        disconnectedAt: DateTime.utc(2026, 10, 3),
      );

      expect(health.requiresReconnect, isFalse);
      expect(health.requiresAccessExtension, isFalse);
    });

    test('disconnected suppresses access extension', () {
      final health = PlaidConnectionHealth(
        connectionId: 'item-1',
        status: PlaidConnectionStatus.active,
        pendingDisconnectAt: DateTime.utc(2026, 11, 15),
        disconnectedAt: DateTime.utc(2026, 10, 3),
      );

      expect(health.requiresAccessExtension, isFalse);
      expect(health.requiresReconnect, isFalse);
    });
  });

  group('requiresAccessExtension', () {
    test('active with pending disconnect requires extension', () {
      final health = PlaidConnectionHealth(
        connectionId: 'item-1',
        status: PlaidConnectionStatus.active,
        pendingDisconnectAt: DateTime.utc(2026, 11, 15),
      );

      expect(health.requiresAccessExtension, isTrue);
      expect(health.requiresReconnect, isFalse);
    });

    test('consent expiry alone does not require extension', () {
      final health = PlaidConnectionHealth(
        connectionId: 'item-1',
        status: PlaidConnectionStatus.active,
        consentExpiresAt: DateTime.utc(2026, 12, 1),
      );

      expect(health.requiresAccessExtension, isFalse);
      expect(health.consentExpiresAt, DateTime.utc(2026, 12, 1));
    });

    test('login_required with pending disconnect requires reconnect only', () {
      final health = PlaidConnectionHealth(
        connectionId: 'item-1',
        status: PlaidConnectionStatus.loginRequired,
        pendingDisconnectAt: DateTime.utc(2026, 11, 15),
      );

      expect(health.requiresAccessExtension, isFalse);
      expect(health.requiresReconnect, isTrue);
    });

    test('healthy connection requires nothing', () {
      const health = PlaidConnectionHealth(
        connectionId: 'item-1',
        status: PlaidConnectionStatus.active,
      );

      expect(health.requiresAccessExtension, isFalse);
      expect(health.requiresReconnect, isFalse);
    });
  });
}

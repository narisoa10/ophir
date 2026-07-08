import 'package:ophir/features/profile/domain/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/profile.dart';
import '../dto/profile_dto.dart';
import '../mappers/profile_mapper.dart';

final class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'profiles';

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<Result<Profile>> getCurrentProfile() async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        return const Failure(NotFoundFailure());
      }

      final profile = ProfileDto.fromJson(data).toEntity();

      return Success(profile);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<Profile>> updateProfile(Profile profile) async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final dto = profile.toDto();

      final data = await _client
          .from(_table)
          .update(dto.toUpdateJson())
          .eq('id', userId)
          .select()
          .single();

      final updatedProfile = ProfileDto.fromJson(data).toEntity();

      return Success(updatedProfile);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Stream<Result<Profile>> watchCurrentProfile() {
    final userId = _currentUserId;

    if (userId == null) {
      return Stream.value(const Failure(UnauthorizedFailure()));
    }

    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map<Result<Profile>>((rows) {
      if (rows.isEmpty) {
        return const Failure(NotFoundFailure());
      }

      final profile = ProfileDto.fromJson(rows.first).toEntity();

      return Success(profile);
    })
        .handleError((Object _) {
      return const Failure<Profile>(UnknownFailure());
    });
  }
}
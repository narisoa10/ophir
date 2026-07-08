import '../../../../core/errors/result.dart';
import '../entities/profile.dart';

abstract interface class ProfileRepository {
  Future<Result<Profile>> getCurrentProfile();

  Future<Result<Profile>> updateProfile(Profile profile);

  Stream<Result<Profile>> watchCurrentProfile();
}
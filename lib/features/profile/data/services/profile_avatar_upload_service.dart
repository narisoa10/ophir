import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';

abstract interface class ProfileAvatarUploadService {
  Future<Result<String?>> uploadAvatar(ImageSource source);
}

final class SupabaseProfileAvatarUploadService
    implements ProfileAvatarUploadService {
  const SupabaseProfileAvatarUploadService(this._client, this._picker);

  final SupabaseClient _client;
  final ImagePicker _picker;

  static const _bucket = 'avatars';

  @override
  Future<Result<String?>> uploadAvatar(ImageSource source) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) {
        return const Success(null);
      }

      final extension = _extensionFor(image);
      final path =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final bytes = await image.readAsBytes();

      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentTypeFor(extension),
              upsert: false,
            ),
          );

      final avatarUrl = _client.storage.from(_bucket).getPublicUrl(path);

      return Success(avatarUrl);
    } on PlatformException {
      return const Failure(PermissionFailure());
    } on StorageException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  String _extensionFor(XFile image) {
    final mimeType = image.mimeType?.toLowerCase();

    if (mimeType == 'image/png') {
      return 'png';
    }

    if (mimeType == 'image/webp') {
      return 'webp';
    }

    final name = image.name.toLowerCase();
    final dotIndex = name.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == name.length - 1) {
      return 'jpg';
    }

    final extension = name.substring(dotIndex + 1);

    return switch (extension) {
      'jpeg' => 'jpg',
      'jpg' || 'png' || 'webp' => extension,
      _ => 'jpg',
    };
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}

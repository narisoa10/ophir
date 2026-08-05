import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure_localization.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../settings/presentation/widgets/settings_scaffold.dart';
import '../../controller/profile_controller.dart';
import '../../domain/entities/profile.dart';
import '../widgets/profile_avatar.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Profile? _profile;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = _profile;

    if (profile == null || !_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(profile.copyWith(fullName: _nameController.text.trim()));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final l10n = AppLocalizations.of(context);

    return SettingsScaffold(
      title: l10n.profileEditTitle,
      actions: [TextButton(onPressed: _save, child: Text(l10n.commonSave))],
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(l10n.failureUnknown)),
        data: (result) {
          return switch (result) {
            Success<Profile>(:final value) => _buildForm(context, value),
            Failure<Profile>(:final failure) => Center(
              child: Text(failure.localized(l10n)),
            ),
            null => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, Profile profile) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;

    _profile = profile;

    if (!_initialized) {
      _nameController.text = profile.fullName ?? '';
      _initialized = true;
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: AppSpacing.screen,
        children: [
          Center(
            child: ProfileAvatar(
              profile: profile,
              radius: AppDimensions.avatarXl,
              editable: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            l10n.profileFullName,
            style: AppTypography.labelLg.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: l10n.profileFullNameHint),
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) {
                return l10n.profileFullNameRequired;
              }

              return null;
            },
            onFieldSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}

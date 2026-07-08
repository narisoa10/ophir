import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../controller/auth_controller.dart';
import '../../controller/auth_state.dart';
import '../mappers/auth_error_mapper.dart';
import '../widgets/auth_divider_text.dart';
import '../widgets/auth_email_section.dart';
import '../widgets/auth_password_section.dart';
import '../widgets/auth_sign_up_suggestion.dart';
import '../widgets/auth_social_button.dart';
import '../widgets/auth_terms_text.dart';

enum AuthMode {
  signIn,
  signUp,
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.initialMode = AuthMode.signIn,
  });

  final AuthMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AuthMode _mode;
  bool _obscurePassword = true;

  bool get _isSignIn => _mode == AuthMode.signIn;
  bool get _isSignUp => _mode == AuthMode.signUp;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _goToSignUp() {
    setState(() {
      _mode = AuthMode.signUp;
    });
  }

  void _showComingSoon() {
    final l10n = AppLocalizations.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.authComingSoon)),
    );
  }

  void _applyEmailSuggestion(String suggestion) {
    _emailController.text = suggestion;
    _emailController.selection = TextSelection.fromPosition(
      TextPosition(offset: _emailController.text.length),
    );

    ref
        .read(authControllerProvider.notifier)
        .updateEmailInput(_emailController.text);
  }

  Future<void> _onContinuePressed() async {
    final controller = ref.read(authControllerProvider.notifier);

    if (_isSignIn) {
      await controller.signInWithEmail(_emailController.text);
      return;
    }

    await controller.signUp(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen<AuthState>(
      authControllerProvider,
          (previous, next) {
        if (previous?.status != next.status &&
            next.status == AuthStatus.emailSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.authCheckEmail)),
          );
        }

        if (next.status == AuthStatus.error && next.errorCode != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorCode!.localized(l10n)),
            ),
          );
        }
      },
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.screenHorizontalOnly,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.maxContentWidth,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxxl,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.xxlRadius,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      AppIcons.logo,
                      width: AppDimensions.avatarMd,
                      height: AppDimensions.avatarMd,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.authWelcome,
                      textAlign: TextAlign.center,
                      style: AppTypography.headingSm,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.authSubtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AuthSocialButton(
                      icon: AppIcons.google,
                      label: l10n.authContinueWithGoogle,
                      onPressed: isLoading
                          ? null
                          : () {
                        ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle();
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AuthDividerText(text: l10n.authOr),
                    const SizedBox(height: AppSpacing.xl),
                    AuthEmailSection(
                      controller: _emailController,
                      authState: authState,
                      l10n: l10n,
                      isLoading: isLoading,
                      onChanged: ref
                          .read(authControllerProvider.notifier)
                          .updateEmailInput,
                      onSuggestionSelected: _applyEmailSuggestion,
                    ),
                    if (_isSignUp)
                      AuthPasswordSection(
                        controller: _passwordController,
                        authState: authState,
                        l10n: l10n,
                        obscurePassword: _obscurePassword,
                        onToggleVisibility: _togglePasswordVisibility,
                        onChanged: ref
                            .read(authControllerProvider.notifier)
                            .updatePasswordInput,
                      ),
                    if (authState.showSignUpSuggestion && _isSignIn)
                      AuthSignUpSuggestion(
                        l10n: l10n,
                        isLoading: isLoading,
                        onSignUpPressed: _goToSignUp,
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(
                      width: double.infinity,
                      height: AppDimensions.buttonLgHeight,
                      child: FilledButton(
                        onPressed: isLoading ? null : _onContinuePressed,
                        child: isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : Text(l10n.authContinue),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AuthTermsText(
                      prefix: l10n.authTermsPrefix,
                      terms: l10n.authTermsOfUse,
                      andText: l10n.authAnd,
                      privacy: l10n.authPrivacyPolicy,
                      onTermsTap: _showComingSoon,
                      onPrivacyTap: _showComingSoon,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
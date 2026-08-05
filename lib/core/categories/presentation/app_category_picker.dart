import 'package:flutter/material.dart';

import '../../icons/app_category_icons.dart';
import '../../icons/app_icons.dart';
import '../../localization/generated/app_localizations.dart';
import '../../theme_v1/app_category_colors.dart';
import '../../theme_v1/app_theme_colors.dart';
import '../../theme_v1/app_dimensions.dart';
import '../../theme_v1/app_radius.dart';
import '../../theme_v1/app_spacing.dart';
import '../../theme_v1/app_typography.dart';
import '../../widgets/app_category_group_section.dart';
import '../../widgets/app_form_field_decoration.dart';
import '../app_categories.dart';

Future<AppCategory?> showAppCategoryPicker({
  required BuildContext context,
  required Iterable<AppCategory> categories,
  AppCategoryId? selectedCategoryId,
}) {
  return showModalBottomSheet<AppCategory>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return _AppCategoryPickerSheet(
        categories: categories.toList(growable: false),
        selectedCategoryId: selectedCategoryId,
      );
    },
  );
}

class AppCategoryPickerField extends StatelessWidget {
  const AppCategoryPickerField({
    required this.categories,
    required this.selectedCategory,
    required this.labelText,
    required this.onCategorySelected,
    this.validator,
    super.key,
  });

  final Iterable<AppCategory> categories;
  final AppCategory? selectedCategory;
  final String labelText;
  final ValueChanged<AppCategory> onCategorySelected;
  final FormFieldValidator<AppCategory>? validator;

  @override
  Widget build(BuildContext context) {
    final categoryList = categories.toList(growable: false);

    return FormField<AppCategory>(
      initialValue: selectedCategory,
      validator: validator,
      builder: (field) {
        final selectedValue = field.value ?? selectedCategory;

        return InkWell(
          borderRadius: AppRadius.inputRadius,
          onTap: () async {
            final selected = await showAppCategoryPicker(
              context: context,
              categories: categoryList,
              selectedCategoryId: selectedValue?.id,
            );

            if (selected == null || !context.mounted) {
              return;
            }

            field.didChange(selected);
            onCategorySelected(selected);
          },
          child: InputDecorator(
            decoration: appFormFieldDecoration(
              context,
              labelText: labelText,
            ).copyWith(errorText: field.errorText),
            child: selectedValue == null
                ? _EmptyCategoryFieldValue(labelText: labelText)
                : _SelectedCategoryFieldValue(category: selectedValue),
          ),
        );
      },
    );
  }
}

class _AppCategoryPickerSheet extends StatefulWidget {
  const _AppCategoryPickerSheet({
    required this.categories,
    required this.selectedCategoryId,
  });

  final List<AppCategory> categories;
  final AppCategoryId? selectedCategoryId;

  @override
  State<_AppCategoryPickerSheet> createState() =>
      _AppCategoryPickerSheetState();
}

class _AppCategoryPickerSheetState extends State<_AppCategoryPickerSheet> {
  late final Set<AppCategoryGroup> _expandedGroups;

  @override
  void initState() {
    super.initState();
    _expandedGroups = {};
  }

  @override
  Widget build(BuildContext context) {
    final groupedCategories = AppCategories.groupByGroup(widget.categories);
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        alignment: Alignment.bottomCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PickerHeader(title: l10n.operationChooseCategory),
            Expanded(
              child: groupedCategories.isEmpty
                  ? Center(
                      child: Text(
                        l10n.operationCategoryPickerEmpty,
                        style: AppTypography.body.copyWith(
                          color: context.appThemeColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: AppSpacing.categoryPickerScreenInsets,
                      itemCount: groupedCategories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final entry = groupedCategories.entries.elementAt(
                          index,
                        );
                        final group = entry.key;
                        final categories = entry.value;
                        final representativeCategory = categories.first;
                        final groupTitle = representativeCategory.groupName(
                          l10n,
                        );
                        final groupIcon = AppCategoryIcons.fromKey(
                          representativeCategory.iconKey,
                        );
                        final groupColor = AppCategoryColors.fromKey(
                          colors,
                          representativeCategory.colorKey,
                        );

                        return AppCategoryGroupSection(
                          isExpanded: _expandedGroups.contains(group),
                          showChildConnector: true,
                          header: _FlatCategoryGroupHeader(
                            key: ValueKey<String>(
                              'app-category-picker-group-${group.name}',
                            ),
                            icon: groupIcon,
                            iconColor: groupColor,
                            title: groupTitle,
                            isExpanded: _expandedGroups.contains(group),
                            onTap: () => _toggleGroup(group),
                          ),
                          children: [
                            for (final category in categories)
                              _FlatCategoryRow(
                                key: ValueKey<String>(
                                  'app-category-picker-category-${category.id.name}',
                                ),
                                title: category.name(l10n),
                                subtitle: category.groupName(l10n),
                                icon: AppCategoryIcons.fromKey(
                                  category.iconKey,
                                ),
                                iconColor: AppCategoryColors.fromKey(
                                  colors,
                                  category.colorKey,
                                ),
                                isSelected:
                                    category.id == widget.selectedCategoryId,
                                onTap: () {
                                  Navigator.of(context).pop(category);
                                },
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleGroup(AppCategoryGroup group) {
    setState(() {
      if (!_expandedGroups.add(group)) {
        _expandedGroups.remove(group);
      }
    });
  }
}

class _FlatCategoryGroupHeader extends StatelessWidget {
  const _FlatCategoryGroupHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.isExpanded,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              SizedBox(
                width: AppDimensions.financialStateHeaderIconBox,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: AppDimensions.iconMd,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.inlineGap),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.inlineGap),
              Icon(
                isExpanded
                    ? AppIcons.actionChevronUp
                    : AppIcons.actionChevronDown,
                color: context.appThemeColors.iconSecondary,
                size: AppDimensions.iconMd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlatCategoryRow extends StatelessWidget {
  const _FlatCategoryRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.compactListTileInsets,
          child: Row(
            children: [
              SizedBox(
                width: AppDimensions.avatarSm,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: AppDimensions.iconSm,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.inlineGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: context.appThemeColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.inlineGap),
              if (isSelected)
                Icon(
                  AppIcons.actionCheck,
                  color: context.appThemeColors.primary,
                  size: AppDimensions.iconSm,
                )
              else
                const SizedBox(width: AppDimensions.iconSm),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCategoryFieldValue extends StatelessWidget {
  const _SelectedCategoryFieldValue({required this.category});

  final AppCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;

    return Row(
      children: [
        Icon(
          AppCategoryIcons.fromKey(category.iconKey),
          color: AppCategoryColors.fromKey(colors, category.colorKey),
          size: AppDimensions.iconMd,
        ),
        const SizedBox(width: AppSpacing.inlineGap),
        Expanded(
          child: Text(
            category.name(l10n),
            style: AppTypography.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.inlineGap),
        Icon(
          AppIcons.actionChevronDown,
          color: context.appThemeColors.iconSecondary,
          size: AppDimensions.iconMd,
        ),
      ],
    );
  }
}

class _EmptyCategoryFieldValue extends StatelessWidget {
  const _EmptyCategoryFieldValue({required this.labelText});

  final String labelText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            labelText,
            style: AppTypography.body.copyWith(
              color: context.appThemeColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.inlineGap),
        Icon(
          AppIcons.actionChevronDown,
          color: context.appThemeColors.iconSecondary,
          size: AppDimensions.iconMd,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/entities/operation.dart';
import '../models/operation_date_section_presentation.dart';
import 'operation_date_section.dart';

class OperationDateSectionList extends StatelessWidget {
  const OperationDateSectionList({
    required this.title,
    required this.hint,
    required this.sections,
    required this.onOperationTap,
    required this.onOperationArchive,
    this.periodHeader,
    this.emptyMessage,
    this.physics,
    super.key,
  });

  final String title;
  final String hint;
  final Widget? periodHeader;
  final String? emptyMessage;
  final ScrollPhysics? physics;
  final List<OperationDateSectionPresentation> sections;
  final ValueChanged<Operation> onOperationTap;
  final Future<bool> Function(Operation operation) onOperationArchive;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: physics,
      itemCount: sections.isEmpty ? 2 : sections.length + 1,
      separatorBuilder: (context, index) {
        return const SizedBox(height: AppSpacing.sectionGap);
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.screenTitle),
              if (periodHeader != null) ...[
                const SizedBox(height: AppSpacing.sm),
                periodHeader!,
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(hint, style: AppTypography.caption),
            ],
          );
        }

        if (sections.isEmpty) {
          return Text(
            emptyMessage ?? '',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          );
        }

        final section = sections[index - 1];

        return OperationDateSection(
          date: MaterialLocalizations.of(
            context,
          ).formatMediumDate(section.date),
          runningBalanceAfterDate: section.runningBalanceAfterDate,
          operations: section.operations,
          onOperationTap: onOperationTap,
          onOperationArchive: onOperationArchive,
        );
      },
    );
  }
}

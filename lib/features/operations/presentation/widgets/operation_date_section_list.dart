import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/operation_list_presentation.dart';
import '../models/operation_presentation.dart';
import 'operation_date_section.dart';

class OperationDateSectionList extends StatelessWidget {
  const OperationDateSectionList({
    required this.title,
    required this.hint,
    required this.presentation,
    required this.onOperationTap,
    required this.onOperationArchive,
    super.key,
  });

  final String title;
  final String hint;
  final OperationListPresentation presentation;
  final ValueChanged<OperationPresentation> onOperationTap;
  final Future<bool> Function(OperationPresentation operation)
  onOperationArchive;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: presentation.sections.length + 1,
      separatorBuilder: (context, index) {
        return const SizedBox(height: AppSpacing.sectionGap);
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.screenTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(hint, style: AppTypography.caption),
            ],
          );
        }

        final section = presentation.sections[index - 1];

        return OperationDateSection(
          date: section.date,
          runningBalanceAfterDate: section.runningBalanceAfterDate,
          operations: section.operations,
          onOperationTap: onOperationTap,
          onOperationArchive: onOperationArchive,
        );
      },
    );
  }
}

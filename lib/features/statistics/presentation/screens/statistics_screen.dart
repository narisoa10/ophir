import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Text(l10n.statisticsTitle),
    );
  }
}
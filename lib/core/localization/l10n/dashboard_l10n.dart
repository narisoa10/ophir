import '../generated/app_localizations.dart';

// TODO: Move Dashboard extension strings into ARB once the Dashboard V1 copy is stable.
extension DashboardL10n on AppLocalizations {
  String get dashboardTodayTitle {
    return switch (localeName) {
      'fr' => "Aujourd'hui",
      'ru' => 'Сегодня',
      _ => 'Today',
    };
  }

  String get dashboardRecordedBalanceTitle {
    return switch (localeName) {
      'fr' => 'Solde enregistré',
      'ru' => 'Записанный баланс',
      _ => 'Recorded balance',
    };
  }

  String get dashboardCashFlowTitle {
    return switch (localeName) {
      'fr' => 'Flux de trésorerie',
      'ru' => 'Денежный поток',
      _ => 'Cash flow',
    };
  }

  String get dashboardInsightsTitle {
    return switch (localeName) {
      'fr' => 'Observations',
      'ru' => 'Инсайты',
      _ => 'Insights',
    };
  }

  String get dashboardUpcomingTitle {
    return switch (localeName) {
      'fr' => 'À venir',
      'ru' => 'Предстоящее',
      _ => 'Upcoming',
    };
  }

  String get dashboardActionsTitle {
    return switch (localeName) {
      'fr' => 'Actions recommandées',
      'ru' => 'Рекомендации',
      _ => 'Recommended actions',
    };
  }

  String get dashboardInsightsEmpty {
    return switch (localeName) {
      'fr' => 'Aucune observation pour le moment.',
      'ru' => 'Пока нет наблюдений.',
      _ => 'No observations yet.',
    };
  }

  String get dashboardActionsEmpty {
    return switch (localeName) {
      'fr' => 'Aucune action recommandee pour le moment.',
      'ru' => 'Пока нет рекомендованных действий.',
      _ => 'No recommended actions yet.',
    };
  }

  String dashboardPreviewItemsCount(int count) {
    return switch (localeName) {
      'fr' => '$count elements',
      'ru' => '$count элементов',
      _ => '$count items',
    };
  }

  String dashboardPreviewUpcomingCount(int count) {
    return switch (localeName) {
      'fr' => '$count operations prevues',
      'ru' => '$count предстоящих операций',
      _ => '$count upcoming operations',
    };
  }

  String get dashboardIncomeLabel {
    return switch (localeName) {
      'fr' => 'Revenus',
      'ru' => 'Доходы',
      _ => 'Income',
    };
  }

  String get dashboardExpensesLabel {
    return switch (localeName) {
      'fr' => 'Depenses',
      'ru' => 'Расходы',
      _ => 'Expenses',
    };
  }

  String get dashboardNetLabel {
    return switch (localeName) {
      'fr' => 'Net',
      'ru' => 'Итог',
      _ => 'Net',
    };
  }

  String get dashboardCashLeftLabel {
    return switch (localeName) {
      'fr' => 'Reste',
      'ru' => 'Остаток',
      _ => 'Cash left',
    };
  }

  String get dashboardPeriodDistributionTitle {
    return switch (localeName) {
      'fr' => 'Repartition du revenu',
      'ru' => 'Распределение дохода',
      _ => 'Income allocation',
    };
  }

  String get dashboardPeriodDistributionSubtitle {
    return switch (localeName) {
      'fr' => 'Comment votre revenu est reparti',
      'ru' => 'Как распределяется ваш доход',
      _ => 'How your income is allocated',
    };
  }

  String get dashboardAllocationMandatory {
    return switch (localeName) {
      'fr' => 'Depenses obligatoires',
      'ru' => 'Обязательные расходы',
      _ => 'Mandatory expenses',
    };
  }

  String get dashboardAllocationWants {
    return switch (localeName) {
      'fr' => 'Envies',
      'ru' => 'Желания',
      _ => 'Wants',
    };
  }

  String get dashboardAllocationSavings {
    return switch (localeName) {
      'fr' => 'Epargne',
      'ru' => 'Сбережения',
      _ => 'Savings',
    };
  }

  String get dashboardAllocationUnallocated {
    return switch (localeName) {
      'fr' => 'Reste / non reparti',
      'ru' => 'Остаток / не распределено',
      _ => 'Left / unallocated',
    };
  }

  String dashboardPeriodLabel(String start, String end) {
    return switch (localeName) {
      'fr' => 'Periode: $start - $end',
      'ru' => 'Период: $start - $end',
      _ => 'Period: $start - $end',
    };
  }

  String dashboardCurrencyLabel(String currencyCode) {
    return switch (localeName) {
      'fr' => 'Devise: $currencyCode',
      'ru' => 'Валюта: $currencyCode',
      _ => 'Currency: $currencyCode',
    };
  }

  String get dashboardStateDeficitTitle {
    return switch (localeName) {
      'fr' => 'Deficit',
      'ru' => 'Дефицит',
      _ => 'Deficit',
    };
  }

  String get dashboardStateDeficitDescription {
    return switch (localeName) {
      'fr' => 'Les depenses depassent les revenus sur la periode.',
      'ru' => 'Расходы превышают доходы за выбранный период.',
      _ => 'Expenses are above income for the selected period.',
    };
  }

  String get dashboardStateFragileBalanceTitle {
    return switch (localeName) {
      'fr' => 'Equilibre fragile',
      'ru' => 'Хрупкое равновесие',
      _ => 'Fragile balance',
    };
  }

  String get dashboardStateFragileBalanceDescription {
    return switch (localeName) {
      'fr' =>
        'Les revenus couvrent les depenses, mais la marge disponible est faible.',
      'ru' =>
        'Доходы покрывают расходы, но запас свободных денег остается небольшим.',
      _ => 'Income covers expenses, but the free margin is still small.',
    };
  }

  String get dashboardStateStableTitle {
    return switch (localeName) {
      'fr' => 'Stable',
      'ru' => 'Стабильно',
      _ => 'Stable',
    };
  }

  String get dashboardStateStableDescription {
    return switch (localeName) {
      'fr' => 'Les revenus couvrent les depenses avec une marge saine.',
      'ru' => 'Доходы покрывают расходы с умеренным запасом.',
      _ => 'Income covers expenses with a healthy margin.',
    };
  }

  String get dashboardStateGrowthTitle {
    return switch (localeName) {
      'fr' => 'Croissance',
      'ru' => 'Рост',
      _ => 'Growth',
    };
  }

  String get dashboardStateGrowthDescription {
    return switch (localeName) {
      'fr' => 'La periode laisse une capacite d epargne notable.',
      'ru' => 'Период оставляет заметный потенциал для сбережений.',
      _ => 'The period leaves meaningful savings capacity.',
    };
  }

  String get dashboardStateStrongPositionTitle {
    return switch (localeName) {
      'fr' => 'Position forte',
      'ru' => 'Сильная позиция',
      _ => 'Strong position',
    };
  }

  String get dashboardStateStrongPositionDescription {
    return switch (localeName) {
      'fr' => 'Les revenus depassent largement les depenses.',
      'ru' => 'Доходы значительно превышают расходы.',
      _ => 'Income is well above expenses.',
    };
  }

  String get dashboardGroupsEmpty {
    return switch (localeName) {
      'fr' => 'Aucune depense categorisee ce mois-ci.',
      'ru' => 'В этом месяце пока нет расходов по категориям.',
      _ => 'No categorized expenses this month.',
    };
  }

  String get dashboardUpcomingEmpty {
    return switch (localeName) {
      'fr' => 'Aucune operation recurrente pour le moment.',
      'ru' => 'Пока нет повторяющихся операций.',
      _ => 'No recurring operations yet.',
    };
  }

  String get dashboardRecordedBalanceDescription {
    return switch (localeName) {
      'fr' =>
        'Base sur les operations enregistrees dans Ophir, pas sur le solde bancaire.',
      'ru' =>
        'Основано на операциях, записанных в Ophir, а не на банковском балансе.',
      _ => 'Based on operations recorded in Ophir, not bank balance.',
    };
  }

  String get dashboardTodayEmpty {
    return switch (localeName) {
      'fr' => 'Aucune operation enregistree aujourd hui.',
      'ru' => 'Сегодня пока нет записанных операций.',
      _ => 'No operations recorded today.',
    };
  }

  String get dashboardTodayPositive {
    return switch (localeName) {
      'fr' => 'La journee est positive pour le moment.',
      'ru' => 'День пока в плюсе.',
      _ => 'Today is positive so far.',
    };
  }

  String get dashboardTodayNegative {
    return switch (localeName) {
      'fr' => 'Les depenses depassent les revenus aujourd hui.',
      'ru' => 'Сегодня расходы выше доходов.',
      _ => 'Expenses are above income today.',
    };
  }

  String get dashboardCashFlowEmpty {
    return switch (localeName) {
      'fr' => 'Aucun flux enregistre ce mois-ci.',
      'ru' => 'В этом месяце пока нет записанного потока.',
      _ => 'No recorded flow this month.',
    };
  }

  String get dashboardCashFlowPositive {
    return switch (localeName) {
      'fr' => 'Les revenus couvrent les depenses ce mois-ci.',
      'ru' => 'Доходы покрывают расходы в этом месяце.',
      _ => 'Income covers expenses this month.',
    };
  }

  String get dashboardCashFlowNegative {
    return switch (localeName) {
      'fr' => 'Les depenses depassent les revenus ce mois-ci.',
      'ru' => 'Расходы выше доходов в этом месяце.',
      _ => 'Expenses are above income this month.',
    };
  }

  String dashboardOperationsCount(int count) {
    return switch (localeName) {
      'fr' => '$count operations',
      'ru' => '$count операций',
      _ => '$count operations',
    };
  }

  String get dashboardAnalyticsEssential {
    return switch (localeName) {
      'fr' => 'Essentiel',
      'ru' => 'Обязательные',
      _ => 'Essential',
    };
  }

  String get dashboardAnalyticsFlexible {
    return switch (localeName) {
      'fr' => 'Flexible',
      'ru' => 'Гибкие',
      _ => 'Flexible',
    };
  }

  String get dashboardAnalyticsLifestyle {
    return switch (localeName) {
      'fr' => 'Style de vie',
      'ru' => 'Образ жизни',
      _ => 'Lifestyle',
    };
  }

  String get dashboardAnalyticsFinance {
    return switch (localeName) {
      'fr' => 'Finance',
      'ru' => 'Финансы',
      _ => 'Finance',
    };
  }

  String get dashboardAnalyticsHealth {
    return switch (localeName) {
      'fr' => 'Sante et developpement',
      'ru' => 'Здоровье и развитие',
      _ => 'Health and development',
    };
  }

  String get dashboardAnalyticsIncome {
    return switch (localeName) {
      'fr' => 'Revenus',
      'ru' => 'Доходы',
      _ => 'Income',
    };
  }

  String get dashboardInsightNoOperationsTitle {
    return switch (localeName) {
      'fr' => 'Aucune donnee financiere',
      'ru' => 'Нет финансовых данных',
      _ => 'No financial data yet',
    };
  }

  String get dashboardInsightNoOperationsDescription {
    return switch (localeName) {
      'fr' =>
        'Ajoutez une operation pour commencer a recevoir des signaux utiles.',
      'ru' =>
        'Добавьте операцию, чтобы Ophir начал показывать полезные сигналы.',
      _ => 'Add an operation so Ophir can start showing useful signals.',
    };
  }

  String get dashboardInsightPositiveCashFlowTitle {
    return switch (localeName) {
      'fr' => 'Flux positif',
      'ru' => 'Положительный поток',
      _ => 'Positive cash flow',
    };
  }

  String dashboardInsightPositiveCashFlowDescription(String amount) {
    return switch (localeName) {
      'fr' =>
        'Le mois est positif de $amount selon les operations enregistrees.',
      'ru' => 'Месяц в плюсе на $amount по записанным операциям.',
      _ => 'This month is positive by $amount from recorded operations.',
    };
  }

  String get dashboardInsightNegativeCashFlowTitle {
    return switch (localeName) {
      'fr' => 'Flux negatif',
      'ru' => 'Отрицательный поток',
      _ => 'Negative cash flow',
    };
  }

  String dashboardInsightNegativeCashFlowDescription(String amount) {
    return switch (localeName) {
      'fr' =>
        'Le mois est negatif de $amount selon les operations enregistrees.',
      'ru' => 'Месяц в минусе на $amount по записанным операциям.',
      _ => 'This month is negative by $amount from recorded operations.',
    };
  }

  String get dashboardInsightTopExpenseGroupTitle {
    return switch (localeName) {
      'fr' => 'Principal poste de depense',
      'ru' => 'Главная группа расходов',
      _ => 'Top expense group',
    };
  }

  String dashboardInsightTopExpenseGroupDescription(
    String group,
    String amount,
  ) {
    return switch (localeName) {
      'fr' => '$group est le plus grand poste ce mois-ci: $amount.',
      'ru' => '$group - крупнейшая группа расходов в этом месяце: $amount.',
      _ => '$group is the largest expense group this month: $amount.',
    };
  }

  String get dashboardInsightLargestOperationTitle {
    return switch (localeName) {
      'fr' => 'Operation la plus importante',
      'ru' => 'Крупнейшая операция',
      _ => 'Largest operation',
    };
  }

  String dashboardInsightLargestOperationDescription(String amount) {
    return switch (localeName) {
      'fr' => 'La plus grande operation enregistree est de $amount.',
      'ru' => 'Самая крупная записанная операция: $amount.',
      _ => 'The largest recorded operation is $amount.',
    };
  }

  String get dashboardInsightUncategorizedTitle {
    return switch (localeName) {
      'fr' => 'Categories manquantes',
      'ru' => 'Не хватает категорий',
      _ => 'Missing categories',
    };
  }

  String dashboardInsightUncategorizedDescription(int count) {
    return switch (localeName) {
      'fr' => '$count operations doivent etre categorisees.',
      'ru' => '$count операций нужно категоризировать.',
      _ => '$count operations need categories.',
    };
  }

  String get dashboardUpcomingRecurringDescription {
    return switch (localeName) {
      'fr' => 'Operation recurrente prevue',
      'ru' => 'Ожидаемая повторяющаяся операция',
      _ => 'Expected recurring operation',
    };
  }

  String get dashboardActionAddFirstOperationTitle {
    return switch (localeName) {
      'fr' => 'Ajoutez votre premiere operation',
      'ru' => 'Добавьте первую операцию',
      _ => 'Add your first operation',
    };
  }

  String get dashboardActionAddFirstOperationDescription {
    return switch (localeName) {
      'fr' =>
        'Ophir a besoin de donnees pour devenir votre assistant financier.',
      'ru' => 'Ophir нужны данные, чтобы стать вашим финансовым ассистентом.',
      _ => 'Ophir needs data to become your financial assistant.',
    };
  }

  String get dashboardActionReviewUncategorizedTitle {
    return switch (localeName) {
      'fr' => 'Classez les operations',
      'ru' => 'Разберите операции',
      _ => 'Review uncategorized operations',
    };
  }

  String dashboardActionReviewUncategorizedDescription(int count) {
    return switch (localeName) {
      'fr' =>
        '$count operations sans categorie reduisent la qualite des insights.',
      'ru' => '$count операций без категории снижают качество инсайтов.',
      _ => '$count operations without categories reduce insight quality.',
    };
  }

  String get dashboardActionReviewTopGroupTitle {
    return switch (localeName) {
      'fr' => 'Verifiez le plus grand poste',
      'ru' => 'Проверьте главную группу',
      _ => 'Review the largest group',
    };
  }

  String dashboardActionReviewTopGroupDescription(String group, String amount) {
    return switch (localeName) {
      'fr' => '$group represente $amount ce mois-ci.',
      'ru' => '$group занимает $amount в этом месяце.',
      _ => '$group accounts for $amount this month.',
    };
  }

  String get dashboardActionCheckCashFlowTitle {
    return switch (localeName) {
      'fr' => 'Corrigez le flux negatif',
      'ru' => 'Проверьте отрицательный поток',
      _ => 'Check negative cash flow',
    };
  }

  String dashboardActionCheckCashFlowDescription(String amount) {
    return switch (localeName) {
      'fr' => 'Le solde du mois est $amount. Revoyez les depenses flexibles.',
      'ru' => 'Итог месяца $amount. Проверьте гибкие расходы.',
      _ => 'This month is $amount. Review flexible expenses.',
    };
  }

  String get dashboardActionAddRecurringTitle {
    return switch (localeName) {
      'fr' => 'Ajoutez les operations recurrentes',
      'ru' => 'Добавьте регулярные операции',
      _ => 'Add recurring operations',
    };
  }

  String get dashboardActionAddRecurringDescription {
    return switch (localeName) {
      'fr' => 'Les revenus et factures recurrentes ameliorent les previsions.',
      'ru' => 'Регулярные доходы и счета улучшают будущий прогноз.',
      _ => 'Recurring income and bills improve future signals.',
    };
  }
}

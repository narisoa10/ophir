import '../generated/app_localizations.dart';
import '../../../features/categories/domain/enums/category_financial_distribution_role.dart';
import '../../../features/categories/domain/enums/spending_pattern.dart';

extension DashboardFinancialStateL10n on AppLocalizations {
  String get dashboardAllocationFlexibleFinal {
    return switch (localeName) {
      'fr' => 'Depenses flexibles',
      'ru' => 'Гибкие расходы',
      _ => 'Flexible expenses',
    };
  }

  String get dashboardAllocationWantsLifestyleFinal {
    return switch (localeName) {
      'fr' => 'Envies / style de vie',
      'ru' => 'Желания / стиль жизни',
      _ => 'Wants / lifestyle',
    };
  }

  String get dashboardDetailButton {
    return switch (localeName) {
      'fr' => 'Details',
      'ru' => 'Подробно',
      _ => 'Details',
    };
  }

  String get dashboardFinancialStateDetailTitle {
    return switch (localeName) {
      'fr' => 'Etat financier',
      'ru' => 'Финансовое состояние',
      _ => 'Financial state',
    };
  }

  String get dashboardStateDeficitTitleFinal {
    return switch (localeName) {
      'fr' => 'Deficit',
      'ru' => 'Дефицит',
      _ => 'Deficit',
    };
  }

  String get dashboardStateFragileBalanceTitleFinal {
    return switch (localeName) {
      'fr' => 'Equilibre fragile',
      'ru' => 'Хрупкое равновесие',
      _ => 'Fragile balance',
    };
  }

  String get dashboardStateStableTitleFinal {
    return switch (localeName) {
      'fr' => 'Stabilite',
      'ru' => 'Стабильность',
      _ => 'Stability',
    };
  }

  String get dashboardStateGrowthTitleFinal {
    return switch (localeName) {
      'fr' => 'Croissance',
      'ru' => 'Рост',
      _ => 'Growth',
    };
  }

  String get dashboardStateStrongPositionTitleFinal {
    return switch (localeName) {
      'fr' => 'Position tres forte',
      'ru' => 'Очень сильное положение',
      _ => 'Very strong position',
    };
  }

  String get dashboardContributorDeficitTitle {
    return switch (localeName) {
      'fr' => 'Ce qui crée le déficit',
      'ru' => 'Что создаёт дефицит',
      _ => 'What creates the deficit',
    };
  }

  String get dashboardContributorFragileTitle {
    return switch (localeName) {
      'fr' => 'Ce qui crée le risque',
      'ru' => 'Что создаёт риск',
      _ => 'What creates the risk',
    };
  }

  String get dashboardContributorStableTitle {
    return switch (localeName) {
      'fr' => 'Ce qui soutient la stabilité',
      'ru' => 'Что поддерживает стабильность',
      _ => 'What supports stability',
    };
  }

  String get dashboardContributorGrowthTitle {
    return switch (localeName) {
      'fr' => 'Ce qui soutient la croissance',
      'ru' => 'Что поддерживает рост',
      _ => 'What supports growth',
    };
  }

  String get dashboardContributorStrongPositionTitle {
    return switch (localeName) {
      'fr' => 'Ce qui crée une position solide',
      'ru' => 'Что создаёт сильную позицию',
      _ => 'What creates a strong position',
    };
  }

  String get dashboardContributorRequiredAmountLabel {
    return switch (localeName) {
      'fr' => 'Montant à couvrir',
      'ru' => 'Необходимо покрыть',
      _ => 'Amount to cover',
    };
  }

  String get dashboardContributorCoveredAmountLabel {
    return switch (localeName) {
      'fr' => 'Montant expliqué par ces catégories',
      'ru' => 'Сумма по выбранным категориям',
      _ => 'Amount represented by these categories',
    };
  }

  String get dashboardContributorEmpty {
    return switch (localeName) {
      'fr' => 'Aucun facteur de catégorie disponible pour cet état.',
      'ru' => 'Нет доступных категорий-факторов для этого состояния.',
      _ => 'No category factors are available for this state.',
    };
  }

  String dashboardContributorPercentOfIncome(String percent) {
    return switch (localeName) {
      'fr' => '$percent du revenu',
      'ru' => '$percent от дохода',
      _ => '$percent of income',
    };
  }

  String dashboardContributorPercentOfExpenses(String percent) {
    return switch (localeName) {
      'fr' => '$percent des dépenses',
      'ru' => '$percent от расходов',
      _ => '$percent of expenses',
    };
  }

  String dashboardContributorDistributionRole(
    CategoryFinancialDistributionRole role,
  ) {
    return switch (role) {
      CategoryFinancialDistributionRole.mandatoryExpenses =>
        switch (localeName) {
          'fr' => 'Charge obligatoire',
          'ru' => 'Обязательная нагрузка',
          _ => 'Mandatory cost',
        },
      CategoryFinancialDistributionRole.flexibleExpenses =>
        switch (localeName) {
          'fr' => 'Dépense flexible',
          'ru' => 'Гибкий расход',
          _ => 'Flexible expense',
        },
      CategoryFinancialDistributionRole.wants => switch (localeName) {
        'fr' => 'Envie / style de vie',
        'ru' => 'Желание / стиль жизни',
        _ => 'Want / lifestyle',
      },
      CategoryFinancialDistributionRole.income => switch (localeName) {
        'fr' => 'Revenu',
        'ru' => 'Доход',
        _ => 'Income',
      },
      CategoryFinancialDistributionRole.assetBuilding => switch (localeName) {
        'fr' => 'Construction d’actifs',
        'ru' => 'Формирование активов',
        _ => 'Asset building',
      },
      CategoryFinancialDistributionRole.debtReduction => switch (localeName) {
        'fr' => 'Réduction de dette',
        'ru' => 'Снижение долга',
        _ => 'Debt reduction',
      },
      CategoryFinancialDistributionRole.cashMovement => switch (localeName) {
        'fr' => 'Mouvement de trésorerie',
        'ru' => 'Движение денег',
        _ => 'Cash movement',
      },
      CategoryFinancialDistributionRole.dataAdjustment => switch (localeName) {
        'fr' => 'Ajustement de données',
        'ru' => 'Корректировка данных',
        _ => 'Data adjustment',
      },
      CategoryFinancialDistributionRole.contextDependent =>
        switch (localeName) {
          'fr' => 'Dépend du contexte',
          'ru' => 'Зависит от контекста',
          _ => 'Context dependent',
        },
    };
  }

  String dashboardContributorSpendingPattern(SpendingPattern pattern) {
    return switch (pattern) {
      SpendingPattern.usuallyRecurring => switch (localeName) {
        'fr' => 'Habituellement récurrent',
        'ru' => 'Обычно повторяется',
        _ => 'Usually recurring',
      },
      SpendingPattern.usuallyVariable => switch (localeName) {
        'fr' => 'Habituellement variable',
        'ru' => 'Обычно переменный',
        _ => 'Usually variable',
      },
      SpendingPattern.periodic => switch (localeName) {
        'fr' => 'Périodique',
        'ru' => 'Периодический',
        _ => 'Periodic',
      },
      SpendingPattern.usuallyOneOff => switch (localeName) {
        'fr' => 'Habituellement ponctuel',
        'ru' => 'Обычно разовый',
        _ => 'Usually one-off',
      },
      SpendingPattern.requiresTransactionEvidence => switch (localeName) {
        'fr' => 'Nécessite des transactions',
        'ru' => 'Требует данных транзакций',
        _ => 'Requires transaction evidence',
      },
      SpendingPattern.unknown => switch (localeName) {
        'fr' => 'Inconnu',
        'ru' => 'Неизвестно',
        _ => 'Unknown',
      },
    };
  }

  String get dashboardFinancialPlanMainProblemTitle {
    return switch (localeName) {
      'fr' => 'Problème principal',
      'ru' => 'Главная проблема',
      _ => 'Main problem',
    };
  }

  String get dashboardFinancialPlanBestEffectTitle {
    return switch (localeName) {
      'fr' => 'Ce qui aura le plus d’effet',
      'ru' => 'Что даст наибольший эффект',
      _ => 'What will have the biggest effect',
    };
  }

  String get dashboardFinancialPlanExpectedResultTitle {
    return switch (localeName) {
      'fr' => 'Résultat attendu',
      'ru' => 'Ожидаемый результат',
      _ => 'Expected result',
    };
  }

  String get dashboardFinancialPlanRecoveryPlanTitle {
    return switch (localeName) {
      'fr' => 'Plan de rétablissement',
      'ru' => 'План восстановления',
      _ => 'Recovery plan',
    };
  }

  String get dashboardFinancialPlanBestEffectPlaceholder {
    return switch (localeName) {
      'fr' =>
        'Les changements minimaux avec l’effet financier maximal seront affichés ici',
      'ru' =>
        'Здесь будут показаны минимальные изменения с максимальным финансовым эффектом',
      _ => 'Minimum changes with maximum financial effect will be shown here',
    };
  }

  String get dashboardFinancialPlanExpectedResultPlaceholder {
    return switch (localeName) {
      'fr' =>
        'Les économies attendues, le nouveau solde et le délai d’amélioration seront affichés ici',
      'ru' =>
        'Здесь будут показаны ожидаемая экономия, новый остаток и срок улучшения состояния',
      _ =>
        'Expected savings, new cash left, and time to improve state will be shown here',
    };
  }

  String get dashboardFinancialPlanRecoveryPlanPlaceholder {
    return switch (localeName) {
      'fr' =>
        'Les étapes dans le temps et un objectif financier positif seront affichés ici',
      'ru' =>
        'Здесь будут показаны временные шаги и положительная финансовая цель',
      _ => 'Time-based steps and a positive financial goal will be shown here',
    };
  }

  String get dashboardFinancialStateDetailWhyTitle {
    return switch (localeName) {
      'fr' => 'Pourquoi cet etat',
      'ru' => 'Почему такое состояние',
      _ => 'Why this state',
    };
  }

  String get dashboardFinancialStateDetailProblemsTitle {
    return switch (localeName) {
      'fr' => 'Problemes trouves',
      'ru' => 'Найденные проблемы',
      _ => 'Problems found',
    };
  }

  String get dashboardFinancialStateDetailNoProblems {
    return switch (localeName) {
      'fr' => 'Aucun probleme prioritaire detecte.',
      'ru' => 'Приоритетные проблемы не обнаружены.',
      _ => 'No priority problems detected.',
    };
  }

  String get dashboardFinancialStateDetailInfluenceTitle {
    return switch (localeName) {
      'fr' => 'Categories et postes influents',
      'ru' => 'Влияющие категории и buckets',
      _ => 'Influencing categories and buckets',
    };
  }

  String get dashboardFinancialStateDetailRecommendationTitle {
    return switch (localeName) {
      'fr' => 'Recommendation de l assistant',
      'ru' => 'Рекомендация ассистента',
      _ => 'Assistant recommendation',
    };
  }

  String get dashboardFinancialStateDetailEvidenceTitle {
    return switch (localeName) {
      'fr' => 'Explication et preuves',
      'ru' => 'Объяснение и evidence',
      _ => 'Explanation and evidence',
    };
  }

  String dashboardProblemDetail(String problem, int signals) {
    return switch (localeName) {
      'fr' => '$problem: $signals signaux.',
      'ru' => '$problem: $signals сигналов.',
      _ => '$problem: $signals signals.',
    };
  }

  String dashboardRecommendationDetail(
    String option,
    String horizon,
    String confidence,
  ) {
    return switch (localeName) {
      'fr' => '$option. Horizon: $horizon. Confiance: $confidence.',
      'ru' => '$option. Горизонт: $horizon. Уверенность: $confidence.',
      _ => '$option. Horizon: $horizon. Confidence: $confidence.',
    };
  }

  String dashboardStateEvidenceModels(int count) {
    return switch (localeName) {
      'fr' => 'Etat calcule avec $count modeles.',
      'ru' => 'Состояние рассчитано по $count моделям.',
      _ => 'State calculated from $count models.',
    };
  }

  String dashboardProblemEvidenceModels(int count) {
    return switch (localeName) {
      'fr' => 'Probleme principal lie a $count modeles sources.',
      'ru' => 'Главная проблема связана с $count исходными моделями.',
      _ => 'Primary problem is linked to $count source models.',
    };
  }

  String dashboardExplanationEvidence(int steps, int nodes) {
    return switch (localeName) {
      'fr' => 'Graphe d explication: $steps etapes, $nodes noeuds.',
      'ru' => 'Граф объяснения: $steps шагов, $nodes узлов.',
      _ => 'Explanation graph: $steps steps, $nodes nodes.',
    };
  }

  String get dashboardExplanationEvidenceUnavailable {
    return switch (localeName) {
      'fr' => 'Aucune explication supplementaire disponible.',
      'ru' => 'Дополнительное объяснение недоступно.',
      _ => 'No additional explanation is available.',
    };
  }
}

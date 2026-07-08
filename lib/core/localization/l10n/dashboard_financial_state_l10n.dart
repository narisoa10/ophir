import '../generated/app_localizations.dart';

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

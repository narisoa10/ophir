import '../generated/app_localizations.dart';

extension DashboardAssistantL10n on AppLocalizations {
  String get dashboardAssistantStateTitle {
    return switch (localeName) {
      'fr' => 'Etat financier',
      'ru' => 'Финансовое состояние',
      _ => 'Financial state',
    };
  }

  String get dashboardAssistantStateStable {
    return switch (localeName) {
      'fr' => 'Les signaux principaux sont stables selon Assistant Core.',
      'ru' => 'Основные сигналы стабильны по данным Assistant Core.',
      _ => 'The main signals are stable according to Assistant Core.',
    };
  }

  String get dashboardAssistantStateWatch {
    return switch (localeName) {
      'fr' => 'Assistant Core voit un point a surveiller ce mois-ci.',
      'ru' => 'Assistant Core видит один главный риск в этом месяце.',
      _ => 'Assistant Core sees one main risk to watch this month.',
    };
  }

  String get dashboardRadarTitle {
    return switch (localeName) {
      'fr' => 'Radar financier',
      'ru' => 'Финансовый радар',
      _ => 'Financial radar',
    };
  }

  String get dashboardRadarLowConfidence {
    return switch (localeName) {
      'fr' => 'Donnees insuffisantes pour certaines axes.',
      'ru' => 'Для части осей пока недостаточно данных.',
      _ => 'Some axes do not have enough evidence yet.',
    };
  }

  String get dashboardLowConfidenceLabel {
    return switch (localeName) {
      'fr' => 'Faible confiance',
      'ru' => 'Низкая уверенность',
      _ => 'Low confidence',
    };
  }

  String get dashboardRadarEvidenceReady {
    return switch (localeName) {
      'fr' => 'Construit depuis les modeles Assistant Core.',
      'ru' => 'Построено из моделей Assistant Core.',
      _ => 'Built from Assistant Core models.',
    };
  }

  String get dashboardRadarCashFlow {
    return switch (localeName) {
      'fr' => 'Cash Flow',
      'ru' => 'Денежный поток',
      _ => 'Cash Flow',
    };
  }

  String get dashboardRadarStability {
    return switch (localeName) {
      'fr' => 'Stabilite',
      'ru' => 'Стабильность',
      _ => 'Stability',
    };
  }

  String get dashboardRadarSpendingControl {
    return switch (localeName) {
      'fr' => 'Controle des depenses',
      'ru' => 'Контроль расходов',
      _ => 'Spending Control',
    };
  }

  String get dashboardRadarSavingsPotential {
    return switch (localeName) {
      'fr' => 'Potentiel d epargne',
      'ru' => 'Потенциал сбережений',
      _ => 'Savings Potential',
    };
  }

  String get dashboardWhyTitle {
    return switch (localeName) {
      'fr' => 'Pourquoi',
      'ru' => 'Почему',
      _ => 'Why',
    };
  }

  String get dashboardWhatNextTitle {
    return switch (localeName) {
      'fr' => 'Ensuite',
      'ru' => 'Что дальше',
      _ => 'What next',
    };
  }

  String get dashboardRecommendedActionTitle {
    return switch (localeName) {
      'fr' => 'Action recommandee',
      'ru' => 'Что сделать',
      _ => 'Recommended action',
    };
  }

  String get dashboardNoMainProblemTitle {
    return switch (localeName) {
      'fr' => 'Aucune cause majeure',
      'ru' => 'Нет главной причины',
      _ => 'No main cause',
    };
  }

  String get dashboardNoMainProblemDescription {
    return switch (localeName) {
      'fr' => 'Assistant Core ne detecte pas de probleme prioritaire.',
      'ru' => 'Assistant Core не нашёл приоритетную проблему.',
      _ => 'Assistant Core did not detect a priority problem.',
    };
  }

  String dashboardProblemTitle(String problem) {
    return switch (localeName) {
      'fr' => 'Cause principale: $problem',
      'ru' => 'Главная причина: $problem',
      _ => 'Main cause: $problem',
    };
  }

  String dashboardProblemEvidence(int signals, int deviations) {
    return switch (localeName) {
      'fr' => '$signals signaux depuis $deviations deviations.',
      'ru' => '$signals сигналов из $deviations отклонений.',
      _ => '$signals signals from $deviations deviations.',
    };
  }

  String dashboardNextFromRecommendation(String horizon) {
    return switch (localeName) {
      'fr' => 'Le prochain effet attendu est $horizon.',
      'ru' => 'Ожидаемый горизонт эффекта: $horizon.',
      _ => 'The next expected effect is $horizon.',
    };
  }

  String get dashboardNextNoRecommendation {
    return switch (localeName) {
      'fr' => 'Continuez a enregistrer les donnees pour affiner la suite.',
      'ru' => 'Продолжайте записывать данные, чтобы уточнить следующий шаг.',
      _ => 'Keep recording data to refine the next step.',
    };
  }

  String get dashboardRecommendationEmptyTitle {
    return switch (localeName) {
      'fr' => 'Continuer a observer',
      'ru' => 'Продолжать наблюдение',
      _ => 'Keep monitoring',
    };
  }

  String get dashboardRecommendationEmptyDescription {
    return switch (localeName) {
      'fr' => 'Aucune action executable n est selectionnee maintenant.',
      'ru' => 'Сейчас нет выбранного исполнимого действия.',
      _ => 'No executable action is selected right now.',
    };
  }

  String dashboardRecommendationConfidence(String confidence) {
    return switch (localeName) {
      'fr' => 'Confiance: $confidence.',
      'ru' => 'Уверенность: $confidence.',
      _ => 'Confidence: $confidence.',
    };
  }

  String get dashboardDetailsTitle {
    return switch (localeName) {
      'fr' => 'Details',
      'ru' => 'Детали',
      _ => 'Details',
    };
  }
}

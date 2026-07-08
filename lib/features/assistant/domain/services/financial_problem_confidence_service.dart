import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_confidence.dart';
import '../entities/financial_deviation_limitation.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_problem_confidence.dart';
import '../entities/financial_problem_limitation.dart';

final class FinancialProblemConfidenceService {
  const FinancialProblemConfidenceService();

  static const int highConfidenceScore = 3;
  static const int mediumConfidenceScore = 2;
  static const int lowConfidenceScore = 1;
  static const int supportingEvidenceBoost = 1;
  static const int limitationPenalty = 1;
  static const int weakDataQualityPenalty = 1;

  FinancialProblemConfidence confidenceFor({
    required List<FinancialDeviation> requiredDeviations,
    required List<FinancialDeviation> supportingDeviations,
    required bool hasWeakDataQuality,
  }) {
    if (requiredDeviations.any(
      (deviation) => deviation.confidence == FinancialDeviationConfidence.none,
    )) {
      return FinancialProblemConfidence.none;
    }

    var score = requiredDeviations
        .map((deviation) => _score(deviation.confidence))
        .reduce((value, element) => value < element ? value : element);

    if (supportingDeviations.isNotEmpty) {
      score += supportingEvidenceBoost;
    } else if (score > lowConfidenceScore) {
      score -= limitationPenalty;
    }
    if (requiredDeviations.any(
          (deviation) => deviation.limitations.isNotEmpty,
        ) ||
        supportingDeviations.any(
          (deviation) => deviation.limitations.isNotEmpty,
        )) {
      if (score > lowConfidenceScore) {
        score -= limitationPenalty;
      }
    }
    if (hasWeakDataQuality &&
        !requiredDeviations.any(
          (deviation) =>
              deviation.deviationType == FinancialDeviationType.weakDataQuality,
        )) {
      if (score > lowConfidenceScore) {
        score -= weakDataQualityPenalty;
      }
    }

    if (score >= highConfidenceScore) {
      return FinancialProblemConfidence.high;
    }
    if (score >= mediumConfidenceScore) {
      return FinancialProblemConfidence.medium;
    }
    if (score >= lowConfidenceScore) {
      return FinancialProblemConfidence.low;
    }
    return FinancialProblemConfidence.none;
  }

  List<FinancialProblemLimitation> limitationsFor({
    required List<FinancialDeviation> deviations,
    required bool hasWeakDataQuality,
    required bool hasLimitedSupportingEvidence,
  }) {
    final limitations = <FinancialProblemLimitation>{};
    if (hasWeakDataQuality) {
      limitations.add(FinancialProblemLimitation.weakDataQuality);
    }
    if (hasLimitedSupportingEvidence) {
      limitations.add(FinancialProblemLimitation.limitedSupportingEvidence);
    }

    for (final deviation in deviations) {
      if (deviation.confidence == FinancialDeviationConfidence.low) {
        limitations.add(FinancialProblemLimitation.lowSourceConfidence);
      }
      for (final limitation in deviation.limitations) {
        switch (limitation) {
          case FinancialDeviationLimitation.sourceMissingCategories:
            limitations.add(FinancialProblemLimitation.sourceMissingCategories);
          case FinancialDeviationLimitation.sourceMissingAccounts:
            limitations.add(FinancialProblemLimitation.sourceMissingAccounts);
          case FinancialDeviationLimitation.sourceMixedCurrencies:
            limitations.add(FinancialProblemLimitation.sourceMixedCurrencies);
          case FinancialDeviationLimitation.sourceZeroIncome:
            limitations.add(FinancialProblemLimitation.sourceZeroIncome);
          case FinancialDeviationLimitation.sourceInsufficientHistory:
            limitations.add(
              FinancialProblemLimitation.sourceInsufficientHistory,
            );
          case FinancialDeviationLimitation.sourceUnknownRecurringPattern:
            limitations.add(
              FinancialProblemLimitation.sourceUnknownRecurringPattern,
            );
          case FinancialDeviationLimitation.lowSourceConfidence:
            limitations.add(FinancialProblemLimitation.lowSourceConfidence);
          case FinancialDeviationLimitation.missingSourceModel:
            limitations.add(
              FinancialProblemLimitation.limitedSupportingEvidence,
            );
        }
      }
    }

    return limitations.toList(growable: false);
  }

  int _score(FinancialDeviationConfidence confidence) {
    return switch (confidence) {
      FinancialDeviationConfidence.high => highConfidenceScore,
      FinancialDeviationConfidence.medium => mediumConfidenceScore,
      FinancialDeviationConfidence.low => lowConfidenceScore,
      FinancialDeviationConfidence.none => 0,
    };
  }
}

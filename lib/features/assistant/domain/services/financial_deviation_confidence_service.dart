import '../entities/financial_deviation_confidence.dart';
import '../entities/financial_deviation_limitation.dart';
import '../entities/financial_model_confidence.dart';
import '../entities/financial_model_limitation.dart';
import '../entities/financial_model_result.dart';

final class FinancialDeviationConfidenceService {
  const FinancialDeviationConfidenceService();

  FinancialDeviationConfidence confidenceFor(
    List<FinancialModelResult> sourceModels,
  ) {
    if (sourceModels.any(
      (model) =>
          model.dataConfidence == FinancialModelConfidence.none ||
          model.modelConfidence == FinancialModelConfidence.none,
    )) {
      return FinancialDeviationConfidence.none;
    }
    if (sourceModels.any(
      (model) =>
          model.dataConfidence == FinancialModelConfidence.low ||
          model.modelConfidence == FinancialModelConfidence.low,
    )) {
      return FinancialDeviationConfidence.low;
    }
    if (sourceModels.any(
      (model) =>
          model.dataConfidence == FinancialModelConfidence.medium ||
          model.modelConfidence == FinancialModelConfidence.medium ||
          model.limitations.any(_reducesConfidence),
    )) {
      return FinancialDeviationConfidence.medium;
    }
    return FinancialDeviationConfidence.high;
  }

  List<FinancialDeviationLimitation> limitationsFor(
    List<FinancialModelResult> sourceModels,
  ) {
    final limitations = <FinancialDeviationLimitation>{};
    for (final model in sourceModels) {
      if (model.dataConfidence == FinancialModelConfidence.low ||
          model.modelConfidence == FinancialModelConfidence.low) {
        limitations.add(FinancialDeviationLimitation.lowSourceConfidence);
      }
      for (final limitation in model.limitations) {
        switch (limitation) {
          case FinancialModelLimitation.missingCategories:
            limitations.add(
              FinancialDeviationLimitation.sourceMissingCategories,
            );
          case FinancialModelLimitation.missingAccounts:
            limitations.add(FinancialDeviationLimitation.sourceMissingAccounts);
          case FinancialModelLimitation.mixedCurrencies:
            limitations.add(FinancialDeviationLimitation.sourceMixedCurrencies);
          case FinancialModelLimitation.zeroIncome:
            limitations.add(FinancialDeviationLimitation.sourceZeroIncome);
          case FinancialModelLimitation.insufficientHistory:
            limitations.add(
              FinancialDeviationLimitation.sourceInsufficientHistory,
            );
          case FinancialModelLimitation.unknownRecurringPattern:
            limitations.add(
              FinancialDeviationLimitation.sourceUnknownRecurringPattern,
            );
          case FinancialModelLimitation.zeroExpense:
          case FinancialModelLimitation.noMatchingFacts:
          case FinancialModelLimitation.unsupportedModel:
          case FinancialModelLimitation.derivedNegativeAmount:
            break;
        }
      }
    }
    return limitations.toList(growable: false);
  }

  bool _reducesConfidence(FinancialModelLimitation limitation) {
    return switch (limitation) {
      FinancialModelLimitation.missingCategories ||
      FinancialModelLimitation.missingAccounts ||
      FinancialModelLimitation.insufficientHistory => true,
      _ => false,
    };
  }
}

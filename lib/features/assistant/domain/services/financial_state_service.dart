import '../entities/financial_model_limitation.dart';
import '../entities/financial_model_period.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';
import '../entities/financial_state.dart';
import '../entities/financial_state_confidence.dart';
import '../entities/financial_state_type.dart';

final class FinancialStateService {
  const FinancialStateService();

  FinancialState evaluate({required List<FinancialModelResult> modelResults}) {
    final byType = {
      for (final result in modelResults) result.modelType: result,
    };
    final income = byType[FinancialModelType.incomeTotal];
    final expenses = byType[FinancialModelType.expenseTotal];
    final net = byType[FinancialModelType.netCashFlow];
    final savingsRate = byType[FinancialModelType.savingsRate];
    final expenseRatio = byType[FinancialModelType.expenseToIncomeRatio];
    final dataQuality = byType[FinancialModelType.dataQualityScore];
    final period = _periodFrom([
      income,
      expenses,
      net,
      savingsRate,
      expenseRatio,
    ]);
    final limitations = _limitations([
      income,
      expenses,
      net,
      savingsRate,
      expenseRatio,
      dataQuality,
    ]);
    final currencyCode = _currencyCode([
      income,
      expenses,
      net,
      savingsRate,
      expenseRatio,
    ]);
    final keyModels = [income, expenses, net, savingsRate, expenseRatio];
    final confidence = _confidence(
      keyModels: keyModels,
      dataQuality: dataQuality,
      limitations: limitations,
    );

    return FinancialState(
      type: _type(
        net: _value(net),
        savingsRate: _value(savingsRate),
        expenseToIncomeRatio: _value(expenseRatio),
      ),
      confidence: confidence,
      period: period,
      currencyCode: currencyCode,
      income: _value(income) ?? 0,
      expenses: _value(expenses) ?? 0,
      net: _value(net) ?? 0,
      evidenceModelIds: _evidenceIds([
        income,
        expenses,
        net,
        savingsRate,
        expenseRatio,
        dataQuality,
      ]),
      limitations: limitations,
    );
  }

  FinancialStateType _type({
    required double? net,
    required double? savingsRate,
    required double? expenseToIncomeRatio,
  }) {
    if ((net ?? 0) < 0 || (expenseToIncomeRatio ?? 0) > 1.0) {
      return FinancialStateType.deficit;
    }
    if (net != null &&
        net >= 0 &&
        ((savingsRate ?? 0) < 0.10 || (expenseToIncomeRatio ?? 0) >= 0.90)) {
      return FinancialStateType.fragileBalance;
    }
    if ((savingsRate ?? -1) >= 0.10 &&
        (savingsRate ?? -1) < 0.20 &&
        (expenseToIncomeRatio ?? 1) < 0.90) {
      return FinancialStateType.stable;
    }
    if ((savingsRate ?? -1) >= 0.20 &&
        (savingsRate ?? -1) < 0.35 &&
        (net ?? 0) > 0) {
      return FinancialStateType.growth;
    }
    if ((savingsRate ?? -1) >= 0.35 &&
        (expenseToIncomeRatio ?? 1) <= 0.65 &&
        (net ?? 0) > 0) {
      return FinancialStateType.strongPosition;
    }
    return FinancialStateType.fragileBalance;
  }

  FinancialStateConfidence _confidence({
    required List<FinancialModelResult?> keyModels,
    required FinancialModelResult? dataQuality,
    required List<FinancialModelLimitation> limitations,
  }) {
    if (keyModels.any((model) => !_isCalculated(model)) ||
        limitations.contains(FinancialModelLimitation.mixedCurrencies)) {
      return FinancialStateConfidence.none;
    }
    if (_value(dataQuality) != null && _value(dataQuality)! < 60) {
      return FinancialStateConfidence.low;
    }
    if (_hasCriticalLimitation(limitations)) {
      return FinancialStateConfidence.low;
    }
    if (limitations.isNotEmpty) {
      return FinancialStateConfidence.medium;
    }
    return FinancialStateConfidence.high;
  }

  bool _hasCriticalLimitation(List<FinancialModelLimitation> limitations) {
    return limitations.any(
      (limitation) =>
          limitation == FinancialModelLimitation.noMatchingFacts ||
          limitation == FinancialModelLimitation.unsupportedModel,
    );
  }

  bool _isCalculated(FinancialModelResult? model) {
    return model?.status == FinancialModelStatus.calculated &&
        model?.value != null;
  }

  double? _value(FinancialModelResult? model) {
    return _isCalculated(model) ? model!.value : null;
  }

  List<FinancialModelLimitation> _limitations(
    List<FinancialModelResult?> models,
  ) {
    return {
      for (final model in models)
        if (model != null) ...model.limitations,
    }.toList(growable: false);
  }

  List<String> _evidenceIds(List<FinancialModelResult?> models) {
    return [
      for (final model in models)
        if (model != null) model.modelId,
    ];
  }

  String? _currencyCode(List<FinancialModelResult?> models) {
    for (final model in models) {
      if (model?.currencyCode != null) {
        return model!.currencyCode;
      }
    }
    return null;
  }

  FinancialModelPeriod _periodFrom(List<FinancialModelResult?> models) {
    for (final model in models) {
      if (model != null) {
        return model.period;
      }
    }
    throw StateError('FinancialState requires at least one model result.');
  }
}

import '../../../assistant/domain/entities/financial_behavior_compatibility_output.dart';
import '../entities/dashboard_compatibility_read_model.dart';
import '../entities/dashboard_financial_summary.dart';

final class DashboardCompatibilityAssembler {
  const DashboardCompatibilityAssembler();

  DashboardCompatibilityReadModel assemble({
    required DashboardFinancialSummary legacySummary,
    required FinancialBehaviorCompatibilityOutput? intelligenceOutput,
  }) {
    return DashboardCompatibilityReadModel(
      legacySummary: legacySummary,
      intelligenceOutput: intelligenceOutput,
    );
  }
}

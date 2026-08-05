import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/theme_v1/app_spacing.dart';
import 'package:ophir/core/widgets/app_editor_bottom_sheet.dart';
import 'package:ophir/core/widgets/app_financial_list_tile.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_household.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_income_source.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_obligation.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_setup.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_confidence.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_source.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_frequency.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/budget_mandatory_expenses_step.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));
final _ruL10n = lookupAppLocalizations(const Locale('ru'));
final _frL10n = lookupAppLocalizations(const Locale('fr'));
const _mandatoryGroups = [
  AppCategoryGroup.housing,
  AppCategoryGroup.transportation,
  AppCategoryGroup.food,
  AppCategoryGroup.health,
  AppCategoryGroup.family,
  AppCategoryGroup.personalCare,
  AppCategoryGroup.education,
  AppCategoryGroup.finance,
  AppCategoryGroup.governmentExpense,
  AppCategoryGroup.pets,
  AppCategoryGroup.giving,
];

void main() {
  group('BudgetMandatoryExpensesStep', () {
    testWidgets('shows mandatory housing categories from AppCategories', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);
      await _expandSection(tester, _groupName(AppCategoryGroup.housing));

      expect(
        find.text(_categoryName(AppCategoryId.expenseHousingRent)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHousingMortgage)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHousingPropertyTax)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHousingInternet)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHousingHomeMaintenance)),
        findsNothing,
      );
    });

    testWidgets('mandatory expense create editor uses shared shell', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);
      await _expandSection(tester, _groupName(AppCategoryGroup.housing));

      await _tapFinancialTileByText(
        tester,
        _categoryName(AppCategoryId.expenseHousingRent),
      );

      expect(find.byType(AppEditorBottomSheet), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
      expect(
        find.widgetWithText(
          TextFormField,
          '${_l10n.budgetExpenseAmount} (CAD)',
        ),
        findsOneWidget,
      );
      expect(find.text(_l10n.commonSave), findsOneWidget);
      expect(find.text(_l10n.commonDelete), findsNothing);
    });

    testWidgets('mandatory expense edit editor uses shared delete action', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(
          obligations: [
            _obligation(
              id: 'rent-obligation',
              categoryId: AppCategoryId.expenseHousingRent.name,
            ),
          ],
        ),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.housing));

      await _tapFinancialTileByText(
        tester,
        _categoryName(AppCategoryId.expenseHousingRent),
      );

      expect(find.byType(AppEditorBottomSheet), findsOneWidget);
      expect(find.text(_l10n.commonDelete), findsOneWidget);
    });

    testWidgets('shows mandatory transport categories from AppCategories', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);
      await _expandSection(tester, _groupName(AppCategoryGroup.transportation));

      expect(
        find.text(
          _categoryName(AppCategoryId.expenseTransportationPublicTransit),
        ),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseTransportationFuel)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseTransportationEvCharging)),
        findsOneWidget,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expenseTransportationAutoInsurance),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expenseTransportationVehicleRegistration),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expenseTransportationTaxiRideSharing),
        ),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseTransportationParking)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseTransportationAutoLoan)),
        findsNothing,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expenseTransportationVehicleMaintenance),
        ),
        findsNothing,
      );
    });

    testWidgets('shows mandatory food categories after transportation', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(find.text(_groupName(AppCategoryGroup.housing)), findsOneWidget);
      expect(
        find.text(_groupName(AppCategoryGroup.transportation)),
        findsOneWidget,
      );
      expect(find.text(_groupName(AppCategoryGroup.food)), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_groupName(AppCategoryGroup.housing))).dy,
        lessThan(
          tester
              .getTopLeft(
                find.text(_groupName(AppCategoryGroup.transportation)),
              )
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(find.text(_groupName(AppCategoryGroup.transportation)))
            .dy,
        lessThan(
          tester.getTopLeft(find.text(_groupName(AppCategoryGroup.food))).dy,
        ),
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodGroceries)),
        findsNothing,
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.food));
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodGroceries)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodFarmersMarket)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodRestaurant)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodCafeCoffee)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodFastFood)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodFoodDelivery)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodSnacks)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodAlcohol)),
        findsNothing,
      );
    });

    testWidgets('shows mandatory health categories after food', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(find.text(_groupName(AppCategoryGroup.food)), findsOneWidget);
      expect(find.text(_groupName(AppCategoryGroup.health)), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_groupName(AppCategoryGroup.food))).dy,
        lessThan(
          tester.getTopLeft(find.text(_groupName(AppCategoryGroup.health))).dy,
        ),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.health));
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthPharmacy)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthMedicine)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthDoctor)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthDentist)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthVisionCare)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthMedicalTests)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthMedicalProcedures)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthHealthInsurance)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthMentalHealth)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthPhysiotherapy)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthGymFitness)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthVitamins)),
        findsNothing,
      );
    });

    testWidgets('shows mandatory family categories after health', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(find.text(_groupName(AppCategoryGroup.health)), findsOneWidget);
      expect(find.text(_groupName(AppCategoryGroup.family)), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_groupName(AppCategoryGroup.health))).dy,
        lessThan(
          tester.getTopLeft(find.text(_groupName(AppCategoryGroup.family))).dy,
        ),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.family));
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyChildcare)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyDaycare)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilySchool)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyUniversity)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyTutoring)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyChildSupport)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyChildrensClothing)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyBabySupplies)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyToys)),
        findsNothing,
      );
    });

    testWidgets('shows mandatory personal care categories after family', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(find.text(_groupName(AppCategoryGroup.family)), findsOneWidget);
      expect(
        find.text(_groupName(AppCategoryGroup.personalCare)),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text(_groupName(AppCategoryGroup.family))).dy,
        lessThan(
          tester
              .getTopLeft(find.text(_groupName(AppCategoryGroup.personalCare)))
              .dy,
        ),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.personalCare));
      expect(
        find.text(
          _categoryName(AppCategoryId.expensePersonalCarePersonalHygiene),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expensePersonalCareContactLenses),
        ),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePersonalCareClothing)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePersonalCareShoes)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePersonalCareCosmetics)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePersonalCareJewelry)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePersonalCareHaircare)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePersonalCareNailCare)),
        findsNothing,
      );
    });

    testWidgets('shows mandatory education category after personal care', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(
        find.text(_groupName(AppCategoryGroup.personalCare)),
        findsOneWidget,
      );
      expect(find.text(_groupName(AppCategoryGroup.education)), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.text(_groupName(AppCategoryGroup.personalCare)))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.text(_groupName(AppCategoryGroup.education)))
              .dy,
        ),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.education));
      expect(
        find.text(
          _categoryName(AppCategoryId.expenseEducationUniversityTuition),
        ),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseEducationCourses)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseEducationOnlineLearning)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseEducationCertifications)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseEducationConferences)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseEducationLanguageCourses)),
        findsNothing,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expenseEducationEducationalMaterials),
        ),
        findsNothing,
      );
    });

    testWidgets('shows mandatory finance categories after education', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(find.text(_groupName(AppCategoryGroup.education)), findsOneWidget);
      expect(find.text(_groupName(AppCategoryGroup.finance)), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_groupName(AppCategoryGroup.education))).dy,
        lessThan(
          tester.getTopLeft(find.text(_groupName(AppCategoryGroup.finance))).dy,
        ),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.finance));
      expect(
        find.text(_categoryName(AppCategoryId.expenseFinanceBankFees)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFinanceAtmFees)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFinanceCurrencyExchange)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFinanceCreditCardPayment)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFinanceLoanPayment)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFinanceDebtRepayment)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseTransportationAutoLoan)),
        findsNothing,
      );
    });

    testWidgets('shows mandatory government categories after finance', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(find.text(_groupName(AppCategoryGroup.finance)), findsOneWidget);
      expect(
        find.text(_groupName(AppCategoryGroup.governmentExpense)),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text(_groupName(AppCategoryGroup.finance))).dy,
        lessThan(
          tester
              .getTopLeft(
                find.text(_groupName(AppCategoryGroup.governmentExpense)),
              )
              .dy,
        ),
      );
      await _expandSection(
        tester,
        _groupName(AppCategoryGroup.governmentExpense),
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseGovernmentIncomeTax)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseGovernmentDriverLicence)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseGovernmentPassport)),
        findsOneWidget,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expenseGovernmentImmigrationFees),
        ),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseGovernmentPermits)),
        findsOneWidget,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expenseGovernmentGovernmentServices),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows mandatory pets categories after government', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(
        find.text(_groupName(AppCategoryGroup.governmentExpense)),
        findsOneWidget,
      );
      expect(find.text(_groupName(AppCategoryGroup.pets)), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.text(_groupName(AppCategoryGroup.governmentExpense)),
            )
            .dy,
        lessThan(
          tester.getTopLeft(find.text(_groupName(AppCategoryGroup.pets))).dy,
        ),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.pets));
      expect(
        find.text(_categoryName(AppCategoryId.expensePetsPetFood)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePetsVeterinary)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePetsPetMedicine)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePetsPetInsurance)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePetsGrooming)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePetsPetSupplies)),
        findsNothing,
      );
    });

    testWidgets('shows mandatory giving category before debt', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(find.text(_groupName(AppCategoryGroup.pets)), findsOneWidget);
      expect(find.text(_groupName(AppCategoryGroup.giving)), findsOneWidget);
      expect(find.text(_l10n.budgetDebtTitle), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_groupName(AppCategoryGroup.pets))).dy,
        lessThan(
          tester.getTopLeft(find.text(_groupName(AppCategoryGroup.giving))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.text(_groupName(AppCategoryGroup.giving))).dy,
        lessThan(tester.getTopLeft(find.text(_l10n.budgetDebtTitle)).dy),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.giving), '0.00 CAD');
    });

    testWidgets('shows debt collection after education', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(find.text(_groupName(AppCategoryGroup.giving)), findsOneWidget);
      expect(find.text(_l10n.budgetDebtTitle), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_groupName(AppCategoryGroup.giving))).dy,
        lessThan(tester.getTopLeft(find.text(_l10n.budgetDebtTitle)).dy),
      );
      expect(find.text(_l10n.budgetDebtAdd), findsNothing);
      await _expandSection(tester, _l10n.budgetDebtTitle);
      expect(find.text(_l10n.budgetDebtAdd), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('all mandatory groups are shown collapsed initially', (
      tester,
    ) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(incomeSources: [_incomeSource(amount: 4000)]),
      );

      for (final group in _mandatoryGroups) {
        expect(find.text(_groupName(group)), findsOneWidget);
      }

      expect(
        find.text(_categoryName(AppCategoryId.expenseHousingRent)),
        findsNothing,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expenseTransportationPublicTransit),
        ),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodGroceries)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthPharmacy)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyChildcare)),
        findsNothing,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expensePersonalCarePersonalHygiene),
        ),
        findsNothing,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expenseEducationUniversityTuition),
        ),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFinanceBankFees)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseGovernmentIncomeTax)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expensePetsPetFood)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseGivingTithe)),
        findsNothing,
      );
      expect(find.text(_l10n.budgetDebtAdd), findsNothing);
    });

    testWidgets('section gaps use compact section spacing token', (
      tester,
    ) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == AppSpacing.sm,
        ),
        findsWidgets,
      );
    });

    testWidgets('tithe label is localized', (tester) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(incomeSources: [_incomeSource(amount: 1000)]),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.giving));
      expect(
        find.text(_categoryName(AppCategoryId.expenseGivingTithe)),
        findsOneWidget,
      );

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        locale: const Locale('ru'),
        setup: _setup(incomeSources: [_incomeSource(amount: 1000)]),
      );
      await _expandSection(tester, _ruL10n.categoryGroupExpenseGiving);
      expect(
        find.text(_ruL10n.categoryTaxonomyExpenseGivingTitheName),
        findsOneWidget,
      );

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        locale: const Locale('fr'),
        setup: _setup(incomeSources: [_incomeSource(amount: 1000)]),
      );
      await _expandSection(tester, _frL10n.categoryGroupExpenseGiving);
      expect(
        find.text(_frL10n.categoryTaxonomyExpenseGivingTitheName),
        findsOneWidget,
      );
    });

    testWidgets('monthly income 4000 creates tithe amount 400', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(incomeSources: [_incomeSource(amount: 4000)]),
      );

      final tithe = _singleTithe(key);

      expect(tithe.amount, 400);
      expect(tithe.frequency, BudgetFrequency.monthly);
      expect(tithe.frequencyInterval, 1);
      expect(tithe.timesPerYear, 12);
    });

    testWidgets('new tithe obligation uses valid uuid id', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(incomeSources: [_incomeSource(amount: 4000)]),
      );

      final tithe = _singleTithe(key);

      expect(_isUuidV4(tithe.id), isTrue);
      expect(tithe.id, isNot(contains(AppCategoryId.expenseGivingTithe.name)));
    });

    testWidgets('tithe uses normalized monthly amount from multiple incomes', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(
          incomeSources: [
            _incomeSource(id: 'monthly-income', amount: 3000),
            _incomeSource(
              id: 'weekly-income',
              amount: 120,
              frequency: BudgetFrequency.weekly,
            ),
          ],
        ),
      );

      expect(_singleTithe(key).amount, 352);
    });

    testWidgets('tithe recalculates when income changes', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(incomeSources: [_incomeSource(amount: 4000)]),
      );
      expect(_singleTithe(key).amount, 400);

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(incomeSources: [_incomeSource(amount: 5000)]),
      );
      expect(_singleTithe(key).amount, 500);
    });

    testWidgets('tithe row contains switch enabled by default', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(incomeSources: [_incomeSource(amount: 4000)]),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.giving));

      final titheSwitch = tester.widget<Switch>(find.byType(Switch));

      expect(titheSwitch.value, isTrue);
      expect(_singleTithe(key).amount, 400);
    });

    testWidgets('switch disables and re-enables tithe', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(incomeSources: [_incomeSource(amount: 4000)]),
      );

      await _expandSection(tester, _groupName(AppCategoryGroup.giving));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text(_l10n.budgetTitheDisabled), findsOneWidget);
      expect(_titheObligations(key), isEmpty);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(_singleTithe(key).amount, 400);
    });

    testWidgets('tap on tithe text does not toggle tithe', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(incomeSources: [_incomeSource(amount: 4000)]),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.giving));
      await _tapFinancialTileByText(
        tester,
        _categoryName(AppCategoryId.expenseGivingTithe),
      );

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(_singleTithe(key).amount, 400);
    });

    testWidgets('disabled tithe label is localized', (tester) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(incomeSources: [_incomeSource(amount: 1000)]),
      );
      await _expandSection(tester, _groupName(AppCategoryGroup.giving));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.budgetTitheDisabled), findsOneWidget);

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        locale: const Locale('ru'),
        setup: _setup(incomeSources: [_incomeSource(amount: 1000)]),
      );
      await _expandSection(tester, _ruL10n.categoryGroupExpenseGiving);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text(_ruL10n.budgetTitheDisabled), findsOneWidget);

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        locale: const Locale('fr'),
        setup: _setup(incomeSources: [_incomeSource(amount: 1000)]),
      );
      await _expandSection(tester, _frL10n.categoryGroupExpenseGiving);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text(_frL10n.budgetTitheDisabled), findsOneWidget);
    });

    testWidgets('tithe switch has semantic label', (tester) async {
      final semantics = tester.ensureSemantics();

      try {
        await _pumpStep(
          tester,
          key: GlobalKey<BudgetMandatoryExpensesStepState>(),
          setup: _setup(incomeSources: [_incomeSource(amount: 1000)]),
        );
        await _expandSection(tester, _groupName(AppCategoryGroup.giving));

        expect(find.bySemanticsLabel('Enable tithe'), findsOneWidget);
        final semantics = tester.getSemantics(find.byType(Switch));

        expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('zero income does not create tithe obligation', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(_titheObligations(key), isEmpty);
    });

    testWidgets(
      'tithe recalculation preserves existing id without duplicates',
      (tester) async {
        final key = GlobalKey<BudgetMandatoryExpensesStepState>();
        const existingTitheId = '54e71d46-166f-46f9-a1c6-a848bcf66df9';

        await _pumpStep(
          tester,
          key: key,
          setup: _setup(
            incomeSources: [_incomeSource(amount: 4000)],
            obligations: [
              _obligation(
                id: existingTitheId,
                categoryId: AppCategoryId.expenseGivingTithe.name,
              ),
            ],
          ),
        );

        final titheObligations = _titheObligations(key);

        expect(titheObligations, hasLength(1));
        expect(titheObligations.single.id, existingTitheId);
        expect(titheObligations.single.amount, 400);
      },
    );

    testWidgets('old invalid tithe id is replaced with uuid', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(
          incomeSources: [_incomeSource(amount: 4000)],
          obligations: [
            _obligation(
              id: 'setup-id-${AppCategoryId.expenseGivingTithe.name}',
              categoryId: AppCategoryId.expenseGivingTithe.name,
            ),
          ],
        ),
      );

      final tithe = _singleTithe(key);

      expect(_isUuidV4(tithe.id), isTrue);
      expect(tithe.id, isNot(contains(AppCategoryId.expenseGivingTithe.name)));
    });

    testWidgets('repeat tithe calculation keeps one generated id', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(incomeSources: [_incomeSource(amount: 4000)]),
      );

      final firstTithe = _singleTithe(key);
      final secondTithe = _singleTithe(key);

      expect(_titheObligations(key), hasLength(1));
      expect(secondTithe.id, firstTithe.id);
      expect(_isUuidV4(secondTithe.id), isTrue);
    });

    testWidgets('food group amount uses filled food expenses', (tester) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.food), '0.00 CAD');

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(
          obligations: [
            _obligation(
              id: 'groceries-obligation',
              categoryId: AppCategoryId.expenseFoodGroceries.name,
            ),
          ],
        ),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.food), '42.00 CAD');

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(
          obligations: [
            _obligation(
              id: 'groceries-obligation',
              categoryId: AppCategoryId.expenseFoodGroceries.name,
            ),
            _obligation(
              id: 'farmers-market-obligation',
              categoryId: AppCategoryId.expenseFoodFarmersMarket.name,
            ),
          ],
        ),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.food), '84.00 CAD');
    });

    testWidgets('group row shows planned amount for filled expenses', (
      tester,
    ) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(
          obligations: [
            _obligation(
              id: 'groceries-obligation',
              categoryId: AppCategoryId.expenseFoodGroceries.name,
              amount: 42,
            ),
            _obligation(
              id: 'farmers-market-obligation',
              categoryId: AppCategoryId.expenseFoodFarmersMarket.name,
              amount: 18,
            ),
          ],
        ),
      );

      _expectSectionAmount(_groupName(AppCategoryGroup.food), '60.00 CAD');
    });

    testWidgets('group row planned amount updates after setup changes', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(
          obligations: [
            _obligation(
              id: 'groceries-obligation',
              categoryId: AppCategoryId.expenseFoodGroceries.name,
              amount: 42,
            ),
          ],
        ),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.food), '42.00 CAD');

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(
          obligations: [
            _obligation(
              id: 'groceries-obligation',
              categoryId: AppCategoryId.expenseFoodGroceries.name,
              amount: 84,
            ),
          ],
        ),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.food), '84.00 CAD');
    });

    testWidgets('empty group row shows zero planned amount', (tester) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
      );

      _expectSectionAmount(_groupName(AppCategoryGroup.food), '0.00 CAD');
    });

    testWidgets('health group amount uses filled health expenses', (
      tester,
    ) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.health), '0.00 CAD');

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(
          obligations: [
            _obligation(
              id: 'pharmacy-obligation',
              categoryId: AppCategoryId.expenseHealthPharmacy.name,
            ),
          ],
        ),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.health), '42.00 CAD');
    });

    testWidgets('family group amount uses filled family expenses', (
      tester,
    ) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.family), '0.00 CAD');

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(
          obligations: [
            _obligation(
              id: 'childcare-obligation',
              categoryId: AppCategoryId.expenseFamilyChildcare.name,
            ),
          ],
        ),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.family), '42.00 CAD');
    });

    testWidgets('personal care group amount uses filled expenses', (
      tester,
    ) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
      );
      _expectSectionAmount(
        _groupName(AppCategoryGroup.personalCare),
        '0.00 CAD',
      );

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(
          obligations: [
            _obligation(
              id: 'personal-hygiene-obligation',
              categoryId: AppCategoryId.expensePersonalCarePersonalHygiene.name,
            ),
          ],
        ),
      );
      _expectSectionAmount(
        _groupName(AppCategoryGroup.personalCare),
        '42.00 CAD',
      );
    });

    testWidgets('education group amount uses filled expenses', (tester) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.education), '0.00 CAD');

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(
          obligations: [
            _obligation(
              id: 'university-tuition-obligation',
              categoryId: AppCategoryId.expenseEducationUniversityTuition.name,
            ),
          ],
        ),
      );
      _expectSectionAmount(_groupName(AppCategoryGroup.education), '42.00 CAD');
    });

    testWidgets(
      'finance government pets and giving amounts use filled expenses',
      (tester) async {
        await _pumpStep(
          tester,
          key: GlobalKey<BudgetMandatoryExpensesStepState>(),
          setup: _setup(
            incomeSources: [_incomeSource(amount: 1000)],
            obligations: [
              _obligation(
                id: 'bank-fees-obligation',
                categoryId: AppCategoryId.expenseFinanceBankFees.name,
              ),
              _obligation(
                id: 'income-tax-obligation',
                categoryId: AppCategoryId.expenseGovernmentIncomeTax.name,
              ),
              _obligation(
                id: 'pet-food-obligation',
                categoryId: AppCategoryId.expensePetsPetFood.name,
              ),
              _obligation(
                id: 'pet-insurance-obligation',
                categoryId: AppCategoryId.expensePetsPetInsurance.name,
              ),
              _obligation(
                id: 'tithe-obligation',
                categoryId: AppCategoryId.expenseGivingTithe.name,
              ),
            ],
          ),
        );

        _expectSectionAmount(_groupName(AppCategoryGroup.finance), '42.00 CAD');
        _expectSectionAmount(
          _groupName(AppCategoryGroup.governmentExpense),
          '42.00 CAD',
        );
        _expectSectionAmount(_groupName(AppCategoryGroup.pets), '84.00 CAD');
        _expectSectionAmount(_groupName(AppCategoryGroup.giving), '100.00 CAD');
      },
    );

    testWidgets('debt group amount uses debt obligations', (tester) async {
      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
      );
      _expectSectionAmount(_l10n.budgetDebtTitle, '0.00 CAD');

      await _pumpStep(
        tester,
        key: GlobalKey<BudgetMandatoryExpensesStepState>(),
        setup: _setup(
          obligations: [
            _debtObligation(id: 'debt-1', name: 'RBC Visa'),
            _debtObligation(id: 'debt-2', name: 'Backup Visa'),
          ],
        ),
      );
      _expectSectionAmount(_l10n.budgetDebtTitle, '84.00 CAD');
    });

    testWidgets('food section collapses and expands without extra controls', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodGroceries)),
        findsNothing,
      );
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      final foodHeader = _sectionHeader(_groupName(AppCategoryGroup.food));
      final screenScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        foodHeader,
        200,
        scrollable: screenScrollable,
      );
      await _tapVisible(tester, foodHeader);

      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodGroceries)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodFarmersMarket)),
        findsOneWidget,
      );

      await _tapVisible(tester, foodHeader);

      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodGroceries)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFoodFarmersMarket)),
        findsNothing,
      );
    });

    testWidgets('health section collapses and expands', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthPharmacy)),
        findsNothing,
      );

      final healthHeader = _sectionHeader(_groupName(AppCategoryGroup.health));
      final screenScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        healthHeader,
        200,
        scrollable: screenScrollable,
      );
      await _tapVisible(tester, healthHeader);

      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthPharmacy)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthMedicine)),
        findsOneWidget,
      );

      await _tapVisible(tester, healthHeader);

      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthPharmacy)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseHealthMedicine)),
        findsNothing,
      );
    });

    testWidgets('family section collapses and expands', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyChildcare)),
        findsNothing,
      );

      final familyHeader = _sectionHeader(_groupName(AppCategoryGroup.family));
      final screenScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        familyHeader,
        200,
        scrollable: screenScrollable,
      );
      await _tapVisible(tester, familyHeader);

      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyChildcare)),
        findsOneWidget,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyDaycare)),
        findsOneWidget,
      );

      await _tapVisible(tester, familyHeader);

      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyChildcare)),
        findsNothing,
      );
      expect(
        find.text(_categoryName(AppCategoryId.expenseFamilyDaycare)),
        findsNothing,
      );
    });

    testWidgets('personal care section collapses and expands', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(
        find.text(
          _categoryName(AppCategoryId.expensePersonalCarePersonalHygiene),
        ),
        findsNothing,
      );
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);

      final personalCareHeader = _sectionHeader(
        _groupName(AppCategoryGroup.personalCare),
      );
      final screenScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        personalCareHeader,
        200,
        scrollable: screenScrollable,
      );
      await _tapVisible(tester, personalCareHeader);

      expect(
        find.text(
          _categoryName(AppCategoryId.expensePersonalCarePersonalHygiene),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expensePersonalCareContactLenses),
        ),
        findsOneWidget,
      );

      await _tapVisible(tester, personalCareHeader);

      expect(
        find.text(
          _categoryName(AppCategoryId.expensePersonalCarePersonalHygiene),
        ),
        findsNothing,
      );
      expect(
        find.text(
          _categoryName(AppCategoryId.expensePersonalCareContactLenses),
        ),
        findsNothing,
      );
    });

    testWidgets('education section collapses and expands', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(
        find.text(
          _categoryName(AppCategoryId.expenseEducationUniversityTuition),
        ),
        findsNothing,
      );
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);

      final educationHeader = _sectionHeader(
        _groupName(AppCategoryGroup.education),
      );
      final screenScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        educationHeader,
        200,
        scrollable: screenScrollable,
      );
      await _tapVisible(tester, educationHeader);

      expect(
        find.text(
          _categoryName(AppCategoryId.expenseEducationUniversityTuition),
        ),
        findsOneWidget,
      );

      await _tapVisible(tester, educationHeader);

      expect(
        find.text(
          _categoryName(AppCategoryId.expenseEducationUniversityTuition),
        ),
        findsNothing,
      );
    });

    testWidgets('add debt opens editor', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);
      await _expandSection(tester, _l10n.budgetDebtTitle);

      final addDebt = _addDebtTile();
      final screenScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        addDebt,
        200,
        scrollable: screenScrollable,
      );
      await _tapVisible(tester, addDebt);

      expect(find.text(_l10n.budgetDebtName), findsOneWidget);
    });

    testWidgets('can add two debts with the same categoryId', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      await _addDebt(tester, name: 'RBC Visa', amount: '250');
      await _addDebt(tester, name: 'Backup Visa', amount: '150');

      final obligations = key.currentState?.validateAndCreateObligations();
      final debts = obligations
          ?.where(
            (obligation) =>
                obligation.categoryId ==
                AppCategoryId.expenseTransportationAutoLoan.name,
          )
          .toList(growable: false);

      expect(debts, hasLength(2));
      expect(debts?.map((obligation) => obligation.id).toSet(), hasLength(2));
      expect(
        debts?.map((obligation) => obligation.name),
        containsAll(['RBC Visa', 'Backup Visa']),
      );
    });

    testWidgets('empty rows do not create obligations', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(tester, key: key);

      expect(key.currentState?.validateAndCreateObligations(), isEmpty);
    });

    testWidgets('keeps filled transport obligations with housing obligations', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();
      final setup = _setup(
        obligations: [
          _obligation(
            id: 'rent-obligation',
            categoryId: AppCategoryId.expenseHousingRent.name,
          ),
          _obligation(
            id: 'transit-obligation',
            categoryId: AppCategoryId.expenseTransportationPublicTransit.name,
          ),
        ],
      );

      await _pumpStep(tester, key: key, setup: setup);

      final obligations = key.currentState?.validateAndCreateObligations();

      expect(
        obligations?.map((obligation) => obligation.id),
        containsAll(['rent-obligation', 'transit-obligation']),
      );
    });

    testWidgets('keeps multiple debts with the same categoryId', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(
          obligations: [
            _obligation(
              id: 'rent-obligation',
              categoryId: AppCategoryId.expenseHousingRent.name,
            ),
            _debtObligation(id: 'debt-1', name: 'RBC Visa'),
            _debtObligation(id: 'debt-2', name: 'Backup Visa'),
          ],
        ),
      );

      final obligations = key.currentState?.validateAndCreateObligations();

      expect(obligations, hasLength(3));
      expect(
        obligations?.map((obligation) => obligation.id),
        containsAll(['rent-obligation', 'debt-1', 'debt-2']),
      );
      expect(
        obligations
            ?.where(
              (obligation) =>
                  obligation.categoryId ==
                  AppCategoryId.expenseFinanceCreditCardPayment.name,
            )
            .map((obligation) => obligation.name),
        containsAll(['RBC Visa', 'Backup Visa']),
      );
    });

    testWidgets('editing debt changes only selected id', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(
          obligations: [
            _debtObligation(id: 'debt-1', name: 'RBC Visa'),
            _debtObligation(id: 'debt-2', name: 'Backup Visa'),
          ],
        ),
      );
      await _expandSection(tester, _l10n.budgetDebtTitle);

      final screenScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      final debtTile = _financialTileByText('RBC Visa');
      await tester.scrollUntilVisible(
        debtTile,
        200,
        scrollable: screenScrollable,
      );
      await _tapVisible(tester, debtTile);
      await tester.enterText(find.byType(TextFormField).first, 'Updated Visa');
      await tester.tap(find.text(_l10n.commonSave));
      await tester.pumpAndSettle();

      final obligations = key.currentState?.validateAndCreateObligations();

      expect(
        obligations
            ?.where((obligation) => obligation.id == 'debt-1')
            .single
            .name,
        'Updated Visa',
      );
      expect(
        obligations
            ?.where((obligation) => obligation.id == 'debt-2')
            .single
            .name,
        'Backup Visa',
      );
    });

    testWidgets('deleting debt removes only selected id', (tester) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(
          obligations: [
            _debtObligation(id: 'debt-1', name: 'RBC Visa'),
            _debtObligation(id: 'debt-2', name: 'Backup Visa'),
          ],
        ),
      );
      await _expandSection(tester, _l10n.budgetDebtTitle);

      final screenScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      final debtTile = _financialTileByText('RBC Visa');
      await tester.scrollUntilVisible(
        debtTile,
        200,
        scrollable: screenScrollable,
      );
      await _tapVisible(tester, debtTile);
      await tester.tap(find.text(_l10n.commonDelete));
      await tester.pumpAndSettle();

      final obligations = key.currentState?.validateAndCreateObligations();

      expect(
        obligations?.map((obligation) => obligation.id),
        isNot(contains('debt-1')),
      );
      expect(
        obligations?.map((obligation) => obligation.id),
        contains('debt-2'),
      );
    });

    testWidgets('transport group amount uses only filled expenses', (
      tester,
    ) async {
      final key = GlobalKey<BudgetMandatoryExpensesStepState>();

      await _pumpStep(
        tester,
        key: key,
        setup: _setup(
          obligations: [
            _obligation(
              id: 'transit-obligation',
              categoryId: AppCategoryId.expenseTransportationPublicTransit.name,
            ),
          ],
        ),
      );

      _expectSectionAmount(
        _groupName(AppCategoryGroup.transportation),
        '42.00 CAD',
      );
    });
  });
}

void _expectSectionAmount(String title, String amount) {
  final header = _sectionHeader(title);

  expect(
    find.descendant(of: header, matching: find.text(amount)),
    findsOneWidget,
  );
}

Future<void> _pumpStep(
  WidgetTester tester, {
  required GlobalKey<BudgetMandatoryExpensesStepState> key,
  BudgetSetup? setup,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BudgetMandatoryExpensesStep(
          key: key,
          setup: setup ?? _setup(),
          currencyCode: 'CAD',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expandSection(WidgetTester tester, String title) async {
  final header = _sectionHeader(title);
  final screenScrollable = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );

  await tester.scrollUntilVisible(header, 200, scrollable: screenScrollable);
  await _tapVisible(tester, header);
}

Finder _sectionHeader(String title) {
  return _financialTileByText(title);
}

Future<void> _addDebt(
  WidgetTester tester, {
  required String name,
  required String amount,
}) async {
  if (find.text(_l10n.budgetDebtAdd).evaluate().isEmpty) {
    await _expandSection(tester, _l10n.budgetDebtTitle);
  }

  final addDebt = _addDebtTile();
  final screenScrollable = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  await tester.scrollUntilVisible(addDebt, 200, scrollable: screenScrollable);
  await _tapVisible(tester, addDebt);
  await tester.enterText(find.byType(TextFormField).at(0), name);
  await tester.enterText(find.byType(TextFormField).at(1), amount);
  await tester.tap(find.text(_l10n.commonSave));
  await tester.pumpAndSettle();
}

Finder _financialTileByText(String text) {
  return find
      .ancestor(
        of: find.text(text),
        matching: find.byType(AppFinancialListTile),
      )
      .first;
}

Finder _addDebtTile() {
  return find
      .ancestor(
        of: find.text(_l10n.budgetDebtAdd),
        matching: find.byType(InkWell),
      )
      .first;
}

Future<void> _tapFinancialTileByText(WidgetTester tester, String text) async {
  await _tapVisible(tester, _financialTileByText(text));
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

BudgetSetup _setup({
  List<BudgetIncomeSource> incomeSources = const [],
  List<BudgetObligation> obligations = const [],
}) {
  final now = DateTime.utc(2026);

  return BudgetSetup(
    id: 'setup-id',
    userId: 'user-id',
    status: 'draft',
    version: 1,
    currentStep: 2,
    household: const BudgetHousehold(adultsCount: 1, childrenCount: 0),
    incomeSources: incomeSources,
    obligations: obligations,
    createdAt: now,
    updatedAt: now,
  );
}

BudgetIncomeSource _incomeSource({
  String id = 'income-source',
  required double amount,
  BudgetFrequency frequency = BudgetFrequency.monthly,
  int? frequencyInterval,
  int? timesPerYear,
}) {
  return BudgetIncomeSource(
    id: id,
    setupId: 'setup-id',
    userId: 'user-id',
    name: 'Main salary',
    categoryId: AppCategoryId.incomeEmploymentSalary.name,
    amount: amount,
    currencyCode: 'CAD',
    frequency: frequency,
    frequencyInterval: frequencyInterval,
    timesPerYear: timesPerYear,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}

BudgetObligation _obligation({
  required String id,
  required String categoryId,
  String obligationType = 'living_expense',
  String? name,
  double amount = 42,
  double? minimumDebtPayment,
}) {
  return BudgetObligation(
    id: id,
    setupId: 'setup-id',
    userId: 'user-id',
    categoryId: categoryId,
    obligationType: obligationType,
    amount: amount,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    nextDueDate: DateTime.utc(2026, 8),
    minimumDebtPayment: minimumDebtPayment,
    name: name,
    isOverdue: false,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}

BudgetObligation _debtObligation({required String id, required String name}) {
  return _obligation(
    id: id,
    categoryId: AppCategoryId.expenseFinanceCreditCardPayment.name,
    obligationType: 'debt_minimum',
    minimumDebtPayment: 42,
    name: name,
  );
}

List<BudgetObligation> _titheObligations(
  GlobalKey<BudgetMandatoryExpensesStepState> key,
) {
  return key.currentState
          ?.validateAndCreateObligations()
          ?.where(
            (obligation) =>
                obligation.categoryId == AppCategoryId.expenseGivingTithe.name,
          )
          .toList(growable: false) ??
      [];
}

BudgetObligation _singleTithe(GlobalKey<BudgetMandatoryExpensesStepState> key) {
  return _titheObligations(key).single;
}

String _categoryName(AppCategoryId id) => AppCategories.byId(id)!.name(_l10n);

String _groupName(AppCategoryGroup group) =>
    AppCategories.mandatoryExpenseCategories(group).first.groupName(_l10n);

bool _isUuidV4(String value) {
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);
}

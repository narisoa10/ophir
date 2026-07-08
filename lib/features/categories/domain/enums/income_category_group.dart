enum IncomeCategoryGroup {
  employment,
  business,
  investments,
  government,
  gifts,
  otherIncome;

  String get l10nKey {
    return switch (this) {
      IncomeCategoryGroup.employment => 'categoryGroupIncomeEmployment',
      IncomeCategoryGroup.business => 'categoryGroupIncomeBusiness',
      IncomeCategoryGroup.investments => 'categoryGroupIncomeInvestments',
      IncomeCategoryGroup.government => 'categoryGroupIncomeGovernment',
      IncomeCategoryGroup.gifts => 'categoryGroupIncomeGifts',
      IncomeCategoryGroup.otherIncome => 'categoryGroupIncomeOtherIncome',
    };
  }
}

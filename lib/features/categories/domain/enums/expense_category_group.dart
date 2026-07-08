enum ExpenseCategoryGroup {
  housing,
  food,
  transportation,
  health,
  family,
  personalCare,
  entertainmentLifestyle,
  education,
  finance,
  government,
  pets,
  giving,
  work,
  other;

  String get l10nKey {
    return switch (this) {
      ExpenseCategoryGroup.housing => 'categoryGroupExpenseHousing',
      ExpenseCategoryGroup.food => 'categoryGroupExpenseFood',
      ExpenseCategoryGroup.transportation =>
        'categoryGroupExpenseTransportation',
      ExpenseCategoryGroup.health => 'categoryGroupExpenseHealth',
      ExpenseCategoryGroup.family => 'categoryGroupExpenseFamily',
      ExpenseCategoryGroup.personalCare => 'categoryGroupExpensePersonalCare',
      ExpenseCategoryGroup.entertainmentLifestyle =>
        'categoryGroupExpenseEntertainmentLifestyle',
      ExpenseCategoryGroup.education => 'categoryGroupExpenseEducation',
      ExpenseCategoryGroup.finance => 'categoryGroupExpenseFinance',
      ExpenseCategoryGroup.government => 'categoryGroupExpenseGovernment',
      ExpenseCategoryGroup.pets => 'categoryGroupExpensePets',
      ExpenseCategoryGroup.giving => 'categoryGroupExpenseGiving',
      ExpenseCategoryGroup.work => 'categoryGroupExpenseWork',
      ExpenseCategoryGroup.other => 'categoryGroupExpenseOther',
    };
  }
}

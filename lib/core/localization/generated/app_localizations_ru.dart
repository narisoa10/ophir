// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get authWelcome => 'Добро пожаловать в Ophir';

  @override
  String get authSubtitle =>
      'Умные финансы.\nВсе ваши финансы в одном приложении.';

  @override
  String get authContinueWithGoogle => 'Продолжить с Google';

  @override
  String get authOr => 'или';

  @override
  String get authEmailHint => 'Введите e-mail';

  @override
  String get authPasswordHint => 'Введите пароль';

  @override
  String get authContinue => 'Продолжить';

  @override
  String get authNoAccount => 'Нет аккаунта?';

  @override
  String get authSignUp => 'Зарегистрироваться';

  @override
  String get authTermsPrefix => 'Продолжая, вы соглашаетесь с';

  @override
  String get authTermsOfUse => 'Условиями использования';

  @override
  String get authAnd => 'и';

  @override
  String get authPrivacyPolicy => 'Политикой конфиденциальности';

  @override
  String get authComingSoon => 'Скоро будет доступно';

  @override
  String get authCheckEmail => 'Проверьте вашу электронную почту.';

  @override
  String get authUserNotFound => 'Аккаунт с этим e-mail не найден.';

  @override
  String get authPasswordRequired => 'Пароль обязателен.';

  @override
  String get authUnknownError => 'Произошла ошибка. Попробуйте ещё раз.';

  @override
  String get authGoogleFailed => 'Не удалось войти через Google.';

  @override
  String get authServerError => 'Ошибка авторизации. Попробуйте ещё раз.';

  @override
  String get authEmailSuggestion => 'Вы имели в виду';

  @override
  String get authRateLimited =>
      'Слишком много запросов по e-mail. Подождите несколько минут и попробуйте снова.';

  @override
  String get emailValidationEmpty => 'E-mail обязателен.';

  @override
  String get emailValidationContainsSpaces =>
      'E-mail не должен содержать пробелы.';

  @override
  String get emailValidationMissingAt => 'E-mail должен содержать \'@\'.';

  @override
  String get emailValidationMultipleAt =>
      'E-mail должен содержать только один \'@\'.';

  @override
  String get emailValidationMissingLocalPart => 'Введите часть перед \'@\'.';

  @override
  String get emailValidationMissingDomain => 'Введите домен e-mail.';

  @override
  String get emailValidationLocalStartsWithDot =>
      'Локальная часть не должна начинаться с \'.\'.';

  @override
  String get emailValidationLocalEndsWithDot =>
      'Локальная часть не должна заканчиваться на \'.\'.';

  @override
  String get emailValidationLocalHasConsecutiveDots =>
      'Локальная часть не должна содержать несколько точек подряд.';

  @override
  String get emailValidationDomainStartsWithDot =>
      'Домен не должен начинаться с \'.\'.';

  @override
  String get emailValidationDomainEndsWithDot =>
      'Домен не должен заканчиваться на \'.\'.';

  @override
  String get emailValidationDomainHasConsecutiveDots =>
      'Домен не должен содержать несколько точек подряд.';

  @override
  String get emailValidationDomainMissingDot => 'Домен должен содержать \'.\'.';

  @override
  String get emailValidationInvalidTopLevelDomain =>
      'Некорректный домен верхнего уровня.';

  @override
  String get emailValidationTopLevelDomainTooShort =>
      'Домен верхнего уровня слишком короткий.';

  @override
  String get emailValidationInvalidLocalCharacters =>
      'Некорректные символы в локальной части.';

  @override
  String get emailValidationInvalidDomainCharacters =>
      'Некорректные символы в домене.';

  @override
  String get emailValidationDomainLabelStartsWithHyphen =>
      'Часть домена не должна начинаться с \'-\'.';

  @override
  String get emailValidationDomainLabelEndsWithHyphen =>
      'Часть домена не должна заканчиваться на \'-\'.';

  @override
  String get emailValidationLocalPartTooLong =>
      'Локальная часть слишком длинная.';

  @override
  String get emailValidationDomainTooLong => 'Домен слишком длинный.';

  @override
  String get emailValidationEmailTooLong => 'E-mail слишком длинный.';

  @override
  String get emailValidationInvalidFormat => 'Некорректный формат e-mail.';

  @override
  String get passwordValidationEmpty => 'Пароль обязателен.';

  @override
  String get passwordValidationContainsSpaces =>
      'Пароль не должен содержать пробелы.';

  @override
  String get passwordValidationTooShort =>
      'Пароль должен содержать минимум 8 символов.';

  @override
  String get passwordValidationTooLong =>
      'Пароль должен содержать не более 128 символов.';

  @override
  String get passwordValidationMissingLetter =>
      'Пароль должен содержать хотя бы одну букву.';

  @override
  String get passwordValidationMissingNumber =>
      'Пароль должен содержать хотя бы одну цифру.';

  @override
  String get passwordValidationMissingSpecialCharacter =>
      'Пароль должен содержать хотя бы один специальный символ.';

  @override
  String get passwordValidationMissingLowercaseLetter =>
      'Пароль должен содержать хотя бы одну строчную букву.';

  @override
  String get passwordValidationMissingUppercaseLetter =>
      'Пароль должен содержать хотя бы одну заглавную букву.';

  @override
  String get passwordRequirementMinLength => 'Минимум 8 символов';

  @override
  String get passwordRequirementMaxLength => 'Не более 128 символов';

  @override
  String get passwordRequirementNoSpaces => 'Без пробелов';

  @override
  String get passwordRequirementLowercase => 'Одна строчная буква';

  @override
  String get passwordRequirementUppercase => 'Одна заглавная буква';

  @override
  String get passwordRequirementNumber => 'Одна цифра';

  @override
  String get passwordRequirementSpecial => 'Один специальный символ';

  @override
  String get passwordStrengthWeak => 'Слабый';

  @override
  String get passwordStrengthMedium => 'Средний';

  @override
  String get passwordStrengthStrong => 'Надёжный';

  @override
  String get failureUnauthorized => 'Войдите в аккаунт, чтобы продолжить.';

  @override
  String get failureNotFound => 'Запрашиваемые данные не найдены.';

  @override
  String get failureValidation => 'Проверьте введённые данные.';

  @override
  String get failureDatabase => 'Произошла ошибка базы данных.';

  @override
  String get failureNetwork =>
      'Ошибка сети. Проверьте подключение к Интернету.';

  @override
  String get failureUnknown => 'Что-то пошло не так.';

  @override
  String get navigationHome => 'Главная';

  @override
  String get navigationAccounts => 'Счета';

  @override
  String get navigationTransactions => 'Операции';

  @override
  String get navigationStatistics => 'Статистика';

  @override
  String get navigationSettings => 'Настройки';

  @override
  String get dashboardGreeting => 'Сегодня';

  @override
  String get accountsTitle => 'Счета';

  @override
  String get transactionsTitle => 'Операции';

  @override
  String get statisticsTitle => 'Статистика';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSectionGeneral => 'ОБЩЕЕ';

  @override
  String get settingsSectionData => 'ДАННЫЕ';

  @override
  String get settingsSectionSecurity => 'БЕЗОПАСНОСТЬ';

  @override
  String get settingsSectionAbout => 'О ПРИЛОЖЕНИИ';

  @override
  String get settingsAppearanceTitle => 'Оформление';

  @override
  String get settingsAppearanceSubtitle => 'Тема и параметры отображения';

  @override
  String get settingsNotificationsTitle => 'Уведомления';

  @override
  String get settingsNotificationsSubtitle => 'Настройки уведомлений';

  @override
  String get settingsAccountsSubtitle => 'Управление счетами и балансами';

  @override
  String get settingsCategoriesTitle => 'Категории';

  @override
  String get settingsCategoriesSubtitle =>
      'Организация категорий доходов и расходов';

  @override
  String get settingsSecurityTitle => 'Безопасность';

  @override
  String get settingsSecuritySubtitle => 'Пароль и безопасность аккаунта';

  @override
  String get settingsAboutTitle => 'О приложении';

  @override
  String get settingsAboutSubtitle => 'Информация о приложении и поддержка';

  @override
  String get settingsPrivacyPolicySubtitle => 'Как обрабатываются ваши данные';

  @override
  String get settingsTermsSubtitle => 'Правила использования Ophir';

  @override
  String get settingsOpenSourceLicensesTitle => 'Лицензии Open Source';

  @override
  String get settingsOpenSourceLicensesSubtitle =>
      'Уведомления сторонних библиотек';

  @override
  String get settingsAppVersionTitle => 'Версия приложения';

  @override
  String get settingsAppVersionSubtitle => 'Сведения о версии';

  @override
  String get settingsComingSoon => 'Скоро будет доступно';

  @override
  String get navigationProfile => 'Профиль';

  @override
  String get profileCurrency => 'Валюта';

  @override
  String get profileTimezone => 'Часовой пояс';

  @override
  String get authSignOut => 'Выйти';

  @override
  String get dashboardGoodMorning => 'Доброе утро';

  @override
  String get navigationOperations => 'Операции';

  @override
  String get operationsTitle => 'Операции';

  @override
  String get dashboardGreetingMorning => 'Доброе утро';

  @override
  String get dashboardGreetingAfternoon => 'Добрый день';

  @override
  String get dashboardGreetingEvening => 'Добрый вечер';

  @override
  String get dashboardGreetingNight => 'Доброй ночи';

  @override
  String get profileNameMissing => 'Добавьте имя';

  @override
  String get profileEditTitle => 'Профиль';

  @override
  String get profileEditSubtitle => 'Имя, фото и личная информация';

  @override
  String get profileSecurityTitle => 'Безопасность';

  @override
  String get profileSecuritySubtitle => 'Пароль и безопасность аккаунта';

  @override
  String get profileNotificationsTitle => 'Уведомления';

  @override
  String get profileNotificationsSubtitle => 'Настройки уведомлений';

  @override
  String get profileAppearanceTitle => 'Оформление';

  @override
  String get profileAppearanceSubtitle => 'Тема и параметры отображения';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get profileFullName => 'Полное имя';

  @override
  String get profileFullNameHint => 'Введите имя';

  @override
  String get profileFullNameRequired => 'Имя обязательно.';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get categoryRent => 'Аренда';

  @override
  String get categoryMortgage => 'Ипотека';

  @override
  String get categoryUtilities => 'Коммунальные услуги';

  @override
  String get categoryInsurance => 'Страхование';

  @override
  String get categoryGroceries => 'Продукты';

  @override
  String get categoryRestaurants => 'Рестораны';

  @override
  String get categoryCoffee => 'Кофе';

  @override
  String get categoryFuel => 'Топливо';

  @override
  String get categoryPublicTransit => 'Общественный транспорт';

  @override
  String get categoryCar => 'Автомобиль';

  @override
  String get categoryHealth => 'Здоровье';

  @override
  String get categoryPharmacy => 'Аптека';

  @override
  String get categoryShopping => 'Покупки';

  @override
  String get categoryEntertainment => 'Развлечения';

  @override
  String get categorySubscriptions => 'Подписки';

  @override
  String get categoryTravel => 'Путешествия';

  @override
  String get categoryEducation => 'Образование';

  @override
  String get categoryDebtPayment => 'Платёж по долгу';

  @override
  String get categoryBankFees => 'Банковские комиссии';

  @override
  String get categorySavings => 'Сбережения';

  @override
  String get categoryInvestments => 'Инвестиции';

  @override
  String get categoryOtherExpense => 'Прочий расход';

  @override
  String get categorySalary => 'Зарплата';

  @override
  String get categoryBusiness => 'Бизнес';

  @override
  String get categoryBenefits => 'Пособия';

  @override
  String get categoryDividends => 'Дивиденды';

  @override
  String get categoryOtherIncome => 'Прочий доход';

  @override
  String get categoryGroupHousing => 'Жильё';

  @override
  String get categoryGroupFood => 'Еда';

  @override
  String get categoryGroupTransport => 'Транспорт';

  @override
  String get categoryGroupHealth => 'Здоровье';

  @override
  String get categoryGroupLifestyle => 'Образ жизни';

  @override
  String get categoryGroupFinance => 'Финансы';

  @override
  String get categoryGroupSalary => 'Зарплата';

  @override
  String get categoryGroupBusiness => 'Бизнес';

  @override
  String get categoryGroupBenefits => 'Пособия';

  @override
  String get categoryGroupInvestments => 'Инвестиции';

  @override
  String get categoryGroupOther => 'Другое';

  @override
  String get categoryExampleDefault => 'Например: Детали операции';

  @override
  String get categoryExampleRent => 'Например: Аренда за июль';

  @override
  String get categoryExampleMortgage => 'Например: Платёж по ипотеке';

  @override
  String get categoryExampleUtilities => 'Например: Электричество';

  @override
  String get categoryExampleInsurance => 'Например: Страховка жилья';

  @override
  String get categoryExampleGroceries => 'Например: Costco';

  @override
  String get categoryExampleRestaurants => 'Например: Ресторан';

  @override
  String get categoryExampleCoffee => 'Например: Кофе';

  @override
  String get categoryExampleFuel => 'Например: Бензин';

  @override
  String get categoryExamplePublicTransit => 'Например: Проездной';

  @override
  String get categoryExampleCar => 'Например: Обслуживание авто';

  @override
  String get categoryExampleHealth => 'Например: Врач';

  @override
  String get categoryExamplePharmacy => 'Например: Аптека';

  @override
  String get categoryExampleShopping => 'Например: Amazon';

  @override
  String get categoryExampleEntertainment => 'Например: Кино';

  @override
  String get categoryExampleSubscriptions => 'Например: Netflix';

  @override
  String get categoryExampleTravel => 'Например: Авиабилет';

  @override
  String get categoryExampleEducation => 'Например: Курс';

  @override
  String get categoryExampleDebtPayment => 'Например: Платёж по кредитке';

  @override
  String get categoryExampleBankFees => 'Например: Банковская комиссия';

  @override
  String get categoryExampleSavings => 'Например: Ежемесячное сбережение';

  @override
  String get categoryExampleInvestments => 'Например: Wealthsimple';

  @override
  String get categoryExampleOtherExpense => 'Например: Прочий расход';

  @override
  String get categoryExampleSalary => 'Например: Зарплата за июнь';

  @override
  String get categoryExampleBusiness => 'Например: Оплата от клиента';

  @override
  String get categoryExampleBenefits => 'Например: Пособие';

  @override
  String get categoryExampleDividends => 'Например: Дивиденды';

  @override
  String get categoryExampleOtherIncome => 'Например: Прочий доход';

  @override
  String get categoryGroupExpenseHousing => 'Жильё';

  @override
  String get categoryGroupExpenseFood => 'Еда';

  @override
  String get categoryGroupExpenseTransportation => 'Транспорт';

  @override
  String get categoryGroupExpenseHealth => 'Здоровье';

  @override
  String get categoryGroupExpenseFamily => 'Семья';

  @override
  String get categoryGroupExpensePersonalCare => 'Уход за собой';

  @override
  String get categoryGroupExpenseEntertainmentLifestyle =>
      'Развлечения и образ жизни';

  @override
  String get categoryGroupExpenseEducation => 'Образование';

  @override
  String get categoryGroupExpenseFinance => 'Финансы';

  @override
  String get categoryGroupExpenseGovernment => 'Государство';

  @override
  String get categoryGroupExpensePets => 'Питомцы';

  @override
  String get categoryGroupExpenseGiving => 'Подарки и помощь';

  @override
  String get categoryGroupExpenseWork => 'Работа';

  @override
  String get categoryGroupExpenseOther => 'Другое';

  @override
  String get categoryGroupIncomeEmployment => 'Работа по найму';

  @override
  String get categoryGroupIncomeBusiness => 'Бизнес';

  @override
  String get categoryGroupIncomeInvestments => 'Инвестиции';

  @override
  String get categoryGroupIncomeGovernment => 'Государство';

  @override
  String get categoryGroupIncomeGifts => 'Подарки';

  @override
  String get categoryGroupIncomeOtherIncome => 'Прочие доходы';

  @override
  String get categoryTaxonomyExpenseHousingRentName => 'Аренда';

  @override
  String get categoryTaxonomyExpenseHousingMortgageName => 'Ипотека';

  @override
  String get categoryTaxonomyExpenseHousingPropertyTaxName =>
      'Налог на недвижимость';

  @override
  String get categoryTaxonomyExpenseHousingCondoFeesName =>
      'Взносы за кондоминиум';

  @override
  String get categoryTaxonomyExpenseHousingElectricityName => 'Электричество';

  @override
  String get categoryTaxonomyExpenseHousingNaturalGasName => 'Природный газ';

  @override
  String get categoryTaxonomyExpenseHousingWaterName => 'Вода';

  @override
  String get categoryTaxonomyExpenseHousingSewerName => 'Канализация';

  @override
  String get categoryTaxonomyExpenseHousingGarbageCollectionName =>
      'Вывоз мусора';

  @override
  String get categoryTaxonomyExpenseHousingInternetName => 'Интернет';

  @override
  String get categoryTaxonomyExpenseHousingMobilePhoneName => 'Мобильная связь';

  @override
  String get categoryTaxonomyExpenseHousingHomePhoneName => 'Домашний телефон';

  @override
  String get categoryTaxonomyExpenseHousingHomeInsuranceName =>
      'Страхование жилья';

  @override
  String get categoryTaxonomyExpenseHousingHomeMaintenanceName =>
      'Ремонт и обслуживание жилья';

  @override
  String get categoryTaxonomyExpenseHousingFurnitureName => 'Мебель';

  @override
  String get categoryTaxonomyExpenseHousingAppliancesName => 'Бытовая техника';

  @override
  String get categoryTaxonomyExpenseHousingHomeSuppliesName =>
      'Товары для дома';

  @override
  String get categoryTaxonomyExpenseHousingHomeSecurityName =>
      'Домашняя безопасность';

  @override
  String get categoryTaxonomyExpenseFoodGroceriesName => 'Продукты';

  @override
  String get categoryTaxonomyExpenseFoodFarmersMarketName => 'Фермерский рынок';

  @override
  String get categoryTaxonomyExpenseFoodRestaurantName => 'Ресторан';

  @override
  String get categoryTaxonomyExpenseFoodCafeCoffeeName => 'Кафе и кофе';

  @override
  String get categoryTaxonomyExpenseFoodFastFoodName => 'Фастфуд';

  @override
  String get categoryTaxonomyExpenseFoodFoodDeliveryName => 'Доставка еды';

  @override
  String get categoryTaxonomyExpenseFoodSnacksName => 'Перекусы';

  @override
  String get categoryTaxonomyExpenseFoodAlcoholName => 'Алкоголь';

  @override
  String get categoryTaxonomyExpenseTransportationFuelName => 'Топливо';

  @override
  String get categoryTaxonomyExpenseTransportationEvChargingName =>
      'Зарядка электромобиля';

  @override
  String get categoryTaxonomyExpenseTransportationPublicTransitName =>
      'Общественный транспорт';

  @override
  String get categoryTaxonomyExpenseTransportationTaxiRideSharingName =>
      'Такси и сервисы поездок';

  @override
  String get categoryTaxonomyExpenseTransportationParkingName => 'Парковка';

  @override
  String get categoryTaxonomyExpenseTransportationTollRoadsName =>
      'Платные дороги';

  @override
  String get categoryTaxonomyExpenseTransportationAutoInsuranceName =>
      'Автострахование';

  @override
  String get categoryTaxonomyExpenseTransportationAutoLoanName => 'Автокредит';

  @override
  String get categoryTaxonomyExpenseTransportationVehicleMaintenanceName =>
      'Обслуживание автомобиля';

  @override
  String get categoryTaxonomyExpenseTransportationTireServiceName =>
      'Шиномонтаж';

  @override
  String get categoryTaxonomyExpenseTransportationVehicleRegistrationName =>
      'Регистрация автомобиля';

  @override
  String get categoryTaxonomyExpenseTransportationCarWashName => 'Автомойка';

  @override
  String get categoryTaxonomyExpenseHealthPharmacyName => 'Аптека';

  @override
  String get categoryTaxonomyExpenseHealthMedicineName => 'Лекарства';

  @override
  String get categoryTaxonomyExpenseHealthDoctorName => 'Врач';

  @override
  String get categoryTaxonomyExpenseHealthDentistName => 'Стоматолог';

  @override
  String get categoryTaxonomyExpenseHealthVisionCareName => 'Зрение';

  @override
  String get categoryTaxonomyExpenseHealthMedicalTestsName =>
      'Медицинские анализы';

  @override
  String get categoryTaxonomyExpenseHealthMedicalProceduresName =>
      'Медицинские процедуры';

  @override
  String get categoryTaxonomyExpenseHealthHealthInsuranceName =>
      'Медицинская страховка';

  @override
  String get categoryTaxonomyExpenseHealthMentalHealthName =>
      'Психическое здоровье';

  @override
  String get categoryTaxonomyExpenseHealthPhysiotherapyName => 'Физиотерапия';

  @override
  String get categoryTaxonomyExpenseHealthGymFitnessName => 'Спортзал и фитнес';

  @override
  String get categoryTaxonomyExpenseHealthVitaminsName => 'Витамины';

  @override
  String get categoryTaxonomyExpenseFamilyChildcareName => 'Уход за детьми';

  @override
  String get categoryTaxonomyExpenseFamilyDaycareName => 'Детский сад';

  @override
  String get categoryTaxonomyExpenseFamilySchoolName => 'Школа';

  @override
  String get categoryTaxonomyExpenseFamilyUniversityName => 'Университет';

  @override
  String get categoryTaxonomyExpenseFamilyTutoringName => 'Репетиторство';

  @override
  String get categoryTaxonomyExpenseFamilyChildrensClothingName =>
      'Детская одежда';

  @override
  String get categoryTaxonomyExpenseFamilyBabySuppliesName =>
      'Товары для младенца';

  @override
  String get categoryTaxonomyExpenseFamilyToysName => 'Игрушки';

  @override
  String get categoryTaxonomyExpenseFamilyChildSupportName =>
      'Алименты на ребёнка';

  @override
  String get categoryTaxonomyExpensePersonalCareClothingName => 'Одежда';

  @override
  String get categoryTaxonomyExpensePersonalCareShoesName => 'Обувь';

  @override
  String get categoryTaxonomyExpensePersonalCareCosmeticsName => 'Косметика';

  @override
  String get categoryTaxonomyExpensePersonalCareJewelryName => 'Украшения';

  @override
  String get categoryTaxonomyExpensePersonalCareHaircareName =>
      'Уход за волосами';

  @override
  String get categoryTaxonomyExpensePersonalCareNailCareName =>
      'Уход за ногтями';

  @override
  String get categoryTaxonomyExpensePersonalCarePersonalHygieneName =>
      'Личная гигиена';

  @override
  String get categoryTaxonomyExpensePersonalCareContactLensesName =>
      'Контактные линзы';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleMoviesName => 'Кино';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleTheatreName =>
      'Театр';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleConcertsName =>
      'Концерты';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleGamingName => 'Игры';

  @override
  String
  get categoryTaxonomyExpenseEntertainmentLifestyleStreamingSubscriptionsName =>
      'Стриминговые подписки';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleMusicName => 'Музыка';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleBooksName => 'Книги';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleHobbiesName =>
      'Хобби';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleTravelName =>
      'Путешествия';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleHotelsName => 'Отели';

  @override
  String get categoryTaxonomyExpenseEducationCoursesName => 'Курсы';

  @override
  String get categoryTaxonomyExpenseEducationOnlineLearningName =>
      'Онлайн-обучение';

  @override
  String get categoryTaxonomyExpenseEducationUniversityTuitionName =>
      'Оплата обучения в университете';

  @override
  String get categoryTaxonomyExpenseEducationCertificationsName =>
      'Сертификации';

  @override
  String get categoryTaxonomyExpenseEducationConferencesName => 'Конференции';

  @override
  String get categoryTaxonomyExpenseEducationLanguageCoursesName =>
      'Языковые курсы';

  @override
  String get categoryTaxonomyExpenseEducationEducationalMaterialsName =>
      'Учебные материалы';

  @override
  String get categoryTaxonomyExpenseFinanceBankFeesName =>
      'Банковские комиссии';

  @override
  String get categoryTaxonomyExpenseFinanceAtmFeesName => 'Комиссии банкомата';

  @override
  String get categoryTaxonomyExpenseFinanceCreditCardPaymentName =>
      'Платёж по кредитной карте';

  @override
  String get categoryTaxonomyExpenseFinanceLoanPaymentName =>
      'Платёж по кредиту';

  @override
  String get categoryTaxonomyExpenseFinanceDebtRepaymentName =>
      'Погашение долга';

  @override
  String get categoryTaxonomyExpenseFinanceSavingsName => 'Сбережения';

  @override
  String get categoryTaxonomyExpenseFinanceEmergencyFundName =>
      'Резервный фонд';

  @override
  String get categoryTaxonomyExpenseFinanceTfsaContributionName =>
      'Взнос в TFSA';

  @override
  String get categoryTaxonomyExpenseFinanceRrspContributionName =>
      'Взнос в RRSP';

  @override
  String get categoryTaxonomyExpenseFinanceRespContributionName =>
      'Взнос в RESP';

  @override
  String get categoryTaxonomyExpenseFinanceInvestmentsName => 'Инвестиции';

  @override
  String get categoryTaxonomyExpenseFinanceCurrencyExchangeName =>
      'Обмен валюты';

  @override
  String get categoryTaxonomyExpenseGovernmentIncomeTaxName =>
      'Подоходный налог';

  @override
  String get categoryTaxonomyExpenseGovernmentDriverLicenceName =>
      'Водительские права';

  @override
  String get categoryTaxonomyExpenseGovernmentPassportName => 'Паспорт';

  @override
  String get categoryTaxonomyExpenseGovernmentImmigrationFeesName =>
      'Иммиграционные сборы';

  @override
  String get categoryTaxonomyExpenseGovernmentPermitsName => 'Разрешения';

  @override
  String get categoryTaxonomyExpenseGovernmentGovernmentServicesName =>
      'Государственные услуги';

  @override
  String get categoryTaxonomyExpensePetsPetFoodName => 'Корм для питомца';

  @override
  String get categoryTaxonomyExpensePetsVeterinaryName => 'Ветеринар';

  @override
  String get categoryTaxonomyExpensePetsPetMedicineName =>
      'Лекарства для питомца';

  @override
  String get categoryTaxonomyExpensePetsPetInsuranceName =>
      'Страхование питомца';

  @override
  String get categoryTaxonomyExpensePetsGroomingName => 'Груминг';

  @override
  String get categoryTaxonomyExpensePetsPetSuppliesName => 'Товары для питомца';

  @override
  String get categoryTaxonomyExpenseGivingGiftsName => 'Подарки';

  @override
  String get categoryTaxonomyExpenseGivingCharityName => 'Благотворительность';

  @override
  String get categoryTaxonomyExpenseGivingDonationsName => 'Пожертвования';

  @override
  String get categoryTaxonomyExpenseGivingHolidayExpensesName =>
      'Праздничные расходы';

  @override
  String get categoryTaxonomyExpenseWorkOfficeSuppliesName =>
      'Офисные принадлежности';

  @override
  String get categoryTaxonomyExpenseWorkSoftwareName =>
      'Программное обеспечение';

  @override
  String get categoryTaxonomyExpenseWorkEquipmentName => 'Оборудование';

  @override
  String get categoryTaxonomyExpenseWorkBusinessTravelName => 'Командировки';

  @override
  String get categoryTaxonomyExpenseWorkProfessionalMembershipsName =>
      'Профессиональные членства';

  @override
  String get categoryTaxonomyExpenseWorkLicencesName => 'Лицензии';

  @override
  String get categoryTaxonomyExpenseOtherCashWithdrawalName =>
      'Снятие наличных';

  @override
  String get categoryTaxonomyExpenseOtherAdjustmentName => 'Корректировка';

  @override
  String get categoryTaxonomyExpenseOtherUncategorizedName => 'Без категории';

  @override
  String get categoryTaxonomyIncomeEmploymentSalaryName => 'Зарплата';

  @override
  String get categoryTaxonomyIncomeEmploymentBonusName => 'Бонус';

  @override
  String get categoryTaxonomyIncomeEmploymentOvertimeName => 'Сверхурочные';

  @override
  String get categoryTaxonomyIncomeEmploymentCommissionName => 'Комиссионные';

  @override
  String get categoryTaxonomyIncomeEmploymentTipsName => 'Чаевые';

  @override
  String get categoryTaxonomyIncomeBusinessBusinessIncomeName =>
      'Доход от бизнеса';

  @override
  String get categoryTaxonomyIncomeBusinessFreelanceName => 'Фриланс';

  @override
  String get categoryTaxonomyIncomeBusinessConsultingName => 'Консалтинг';

  @override
  String get categoryTaxonomyIncomeBusinessRentalIncomeName =>
      'Доход от аренды';

  @override
  String get categoryTaxonomyIncomeInvestmentsInterestIncomeName =>
      'Процентный доход';

  @override
  String get categoryTaxonomyIncomeInvestmentsDividendIncomeName => 'Дивиденды';

  @override
  String get categoryTaxonomyIncomeInvestmentsCapitalGainsName =>
      'Прирост капитала';

  @override
  String get categoryTaxonomyIncomeInvestmentsInvestmentDistributionName =>
      'Инвестиционная выплата';

  @override
  String get categoryTaxonomyIncomeGovernmentTaxRefundName => 'Возврат налога';

  @override
  String get categoryTaxonomyIncomeGovernmentGovernmentBenefitsName =>
      'Государственные пособия';

  @override
  String get categoryTaxonomyIncomeGovernmentPensionName => 'Пенсия';

  @override
  String get categoryTaxonomyIncomeGovernmentChildBenefitName =>
      'Детское пособие';

  @override
  String get categoryTaxonomyIncomeGovernmentEmploymentInsuranceName =>
      'Страхование занятости';

  @override
  String get categoryTaxonomyIncomeGiftsGiftReceivedName =>
      'Полученный подарок';

  @override
  String get categoryTaxonomyIncomeGiftsFamilySupportName => 'Поддержка семьи';

  @override
  String get categoryTaxonomyIncomeGiftsCashbackName => 'Кэшбэк';

  @override
  String get categoryTaxonomyIncomeGiftsRewardsName => 'Вознаграждения';

  @override
  String get categoryTaxonomyIncomeOtherIncomeRefundName => 'Возврат средств';

  @override
  String get categoryTaxonomyIncomeOtherIncomeReimbursementName =>
      'Компенсация';

  @override
  String get categoryTaxonomyIncomeOtherIncomeSaleOfItemName => 'Продажа вещи';

  @override
  String get categoryTaxonomyIncomeOtherIncomeOtherIncomeName => 'Прочий доход';

  @override
  String get operationExpense => 'Расход';

  @override
  String get operationIncome => 'Доход';

  @override
  String get operationTransfer => 'Перевод';

  @override
  String get operationCreateTitle => 'Операция';

  @override
  String get operationEditTitle => 'Редактировать операцию';

  @override
  String get operationExpenseNameHint => 'Название расхода';

  @override
  String get operationIncomeNameHint => 'Название дохода';

  @override
  String get operationAmountHint => 'Сумма';

  @override
  String get operationChooseCategory => 'Выбрать категорию';

  @override
  String get operationCategoryPickerEmpty => 'Нет доступных категорий.';

  @override
  String get dashboardPercentLessThanOne => '<1%';

  @override
  String get commonApply => 'Применить';

  @override
  String get operationArchiveTitle => 'Удалить операцию?';

  @override
  String get operationArchiveMessage =>
      'Операция будет архивирована и скрыта из списка.';

  @override
  String get operationArchiveConfirm => 'Удалить';

  @override
  String get operationsInteractionHint =>
      'Нажмите, чтобы изменить · Смахните влево, чтобы удалить';

  @override
  String get operationsEmptyMessage =>
      'У вас пока нет доходов или расходов.\nНажмите +, чтобы добавить первую операцию.';

  @override
  String get operationRecurrenceNone => 'Без повторения';

  @override
  String get operationRecurrenceDaily => 'Ежедневно';

  @override
  String get operationRecurrenceWeekly => 'Еженедельно';

  @override
  String get operationRecurrenceBiweekly => 'Раз в 2 недели';

  @override
  String get operationRecurrenceMonthly => 'Ежемесячно';

  @override
  String get operationRecurrenceYearly => 'Ежегодно';

  @override
  String get operationRecurrenceTitle => 'Повторяемость';

  @override
  String get operationDescriptionHint => 'Описание';

  @override
  String get commonSaving => 'Сохранение...';

  @override
  String get operationAmountRequired => 'Введите корректную сумму.';

  @override
  String get operationCategoryRequired => 'Выберите категорию.';

  @override
  String get accountsEmptyMessage =>
      'У вас пока нет ни одного счета.\nНажмите +, чтобы создать первый счет.';

  @override
  String get accountCreateTitle => 'Создать счёт';

  @override
  String get accountNameHint => 'Название счёта';

  @override
  String get accountNameRequired => 'Название счёта обязательно.';

  @override
  String get accountTypeHint => 'Тип счёта';

  @override
  String get accountCurrencyHint => 'Валюта';

  @override
  String get accountInitialBalanceHint => 'Начальный баланс';

  @override
  String get accountInitialBalanceRequired => 'Начальный баланс обязателен.';

  @override
  String get accountInitialBalanceInvalid => 'Введите корректную сумму.';

  @override
  String get accountTypeCash => 'Наличные';

  @override
  String get accountTypeBank => 'Банк';

  @override
  String get accountTypeCard => 'Карта';

  @override
  String get accountTypeCreditCard => 'Кредитная карта';

  @override
  String get accountTypeSavings => 'Сбережения';

  @override
  String get accountTypeInvestment => 'Инвестиции';

  @override
  String get accountTypeLoan => 'Кредит';

  @override
  String get accountTypeWallet => 'Кошелёк';

  @override
  String get accountTypeOther => 'Другое';
}

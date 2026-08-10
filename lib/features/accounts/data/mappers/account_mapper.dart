import '../../domain/entities/account.dart';
import '../../domain/enums/account_type.dart';
import '../dto/account_dto.dart';

extension AccountDtoMapper on AccountDto {
  Account toEntity() {
    return Account(
      id: id,
      userId: userId,
      name: name,
      type: type == null ? null : AccountType.fromJson(type!),
      currencyCode: currencyCode,
      unofficialCurrencyCode: unofficialCurrencyCode,
      initialBalance: initialBalance,
      iconKey: iconKey,
      colorKey: colorKey,
      sortOrder: sortOrder,
      isArchived: isArchived,
      isIncludedInFinances: isIncludedInFinances,
      createdAt: createdAt,
      updatedAt: updatedAt,
      plaidItemId: plaidItemId,
      institutionId: institutionId,
      plaidAccountId: plaidAccountId,
      officialName: officialName,
      mask: mask,
      plaidType: plaidType,
      plaidSubtype: plaidSubtype,
      currentBalance: currentBalance,
      availableBalance: availableBalance,
      balanceFetchedAt: balanceFetchedAt,
    );
  }
}

extension AccountEntityMapper on Account {
  AccountDto toDto() {
    return AccountDto(
      id: id,
      userId: userId,
      name: name,
      type: type?.toJson(),
      currencyCode: currencyCode,
      unofficialCurrencyCode: unofficialCurrencyCode,
      initialBalance: initialBalance,
      iconKey: iconKey,
      colorKey: colorKey,
      sortOrder: sortOrder,
      isArchived: isArchived,
      isIncludedInFinances: isIncludedInFinances,
      createdAt: createdAt,
      updatedAt: updatedAt,
      plaidItemId: plaidItemId,
      institutionId: institutionId,
      plaidAccountId: plaidAccountId,
      officialName: officialName,
      mask: mask,
      plaidType: plaidType,
      plaidSubtype: plaidSubtype,
      currentBalance: currentBalance,
      availableBalance: availableBalance,
      balanceFetchedAt: balanceFetchedAt,
    );
  }
}

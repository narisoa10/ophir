import '../../domain/entities/account.dart';
import '../../domain/enums/account_type.dart';
import '../dto/account_dto.dart';

extension AccountDtoMapper on AccountDto {
  Account toEntity() {
    return Account(
      id: id,
      userId: userId,
      name: name,
      type: AccountType.fromJson(type),
      currencyCode: currencyCode,
      initialBalance: initialBalance,
      iconKey: iconKey,
      colorKey: colorKey,
      sortOrder: sortOrder,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension AccountEntityMapper on Account {
  AccountDto toDto() {
    return AccountDto(
      id: id,
      userId: userId,
      name: name,
      type: type.toJson(),
      currencyCode: currencyCode,
      initialBalance: initialBalance,
      iconKey: iconKey,
      colorKey: colorKey,
      sortOrder: sortOrder,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
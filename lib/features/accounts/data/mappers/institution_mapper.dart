import '../../domain/entities/institution.dart';
import '../dto/institution_dto.dart';

extension InstitutionDtoMapper on InstitutionDto {
  Institution toEntity() {
    return Institution(
      id: id,
      userId: userId,
      plaidItemId: plaidItemId,
      plaidInstitutionId: plaidInstitutionId,
      name: name,
      logoBase64: logoBase64,
      primaryColor: primaryColor,
      url: url,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

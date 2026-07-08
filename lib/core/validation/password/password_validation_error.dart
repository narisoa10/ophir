enum PasswordValidationError {
  empty,
  containsSpaces,
  tooShort,
  tooLong,
  missingLowercaseLetter,
  missingUppercaseLetter,
  missingNumber,
  missingSpecialCharacter,
}
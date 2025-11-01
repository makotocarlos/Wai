class EmailConfirmationRequiredException implements Exception {
  const EmailConfirmationRequiredException(this.message);

  final String message;

  @override
  String toString() => 'EmailConfirmationRequiredException: $message';
}

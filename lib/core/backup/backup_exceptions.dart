/// Errors raised by backup / restore operations (safe to show to users).
sealed class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BackupCancelledException extends BackupException {
  const BackupCancelledException([super.message = 'Backup cancelled.']);
}

class BackupValidationException extends BackupException {
  const BackupValidationException(super.message);
}

class BackupIncompatibleException extends BackupException {
  const BackupIncompatibleException(super.message);
}

class BackupIoException extends BackupException {
  const BackupIoException(super.message);
}

class RestoreFailedException extends BackupException {
  const RestoreFailedException(super.message);
}

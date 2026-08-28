class BackupService {
  BackupService({Object? database});
  Future<String> createBackup({
    required int adminId,
    required String destinationFolder,
  }) => _unsupported();
  Future<void> validateBackup(String sourcePath) => _unsupported();
  Future<String> restoreDatabase({
    required int adminId,
    required String sourcePath,
  }) => _unsupported();
  Future<String?> databasePath() async => null;
  Future<T> _unsupported<T>() =>
      Future.error(const BackupUnsupportedException());
}

class BackupUnsupportedException implements Exception {
  const BackupUnsupportedException();
}

class InvalidBackupException implements Exception {
  const InvalidBackupException(this.message);
  final String message;
}

class AppValidators {
  const AppValidators._();

  static String? requiredText(Object? value, String label) {
    if (value?.toString().trim().isEmpty ?? true) return '$label is required.';
    return null;
  }

  static String? nic(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^\d{9}[VvXx]$').hasMatch(text) &&
        !RegExp(r'^\d{12}$').hasMatch(text))
      return 'Enter a valid NIC.';
    return null;
  }

  static String? phone(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^(?:0\d{9}|\+94\d{9})$').hasMatch(text))
      return 'Enter a valid phone number.';
    return null;
  }

  static String? date(Object? value, String label) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '$label is required.';
    if (DateTime.tryParse(text) == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text))
      return '$label must use YYYY-MM-DD.';
    return null;
  }

  static String? optionalDate(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : date(text, 'Date');
  }
}

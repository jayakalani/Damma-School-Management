import 'package:flutter/material.dart';

/// Shared YYYY-MM-DD helpers used by forms and validators.
class AppDateFormats {
  const AppDateFormats._();

  static String storage(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static DateTime? parseStorage(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.trim().split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}

/// Database/form keys that should use a calendar picker.
bool isStorageDateFieldKey(String key) =>
    key == 'date_of_birth' ||
    key == 'registered_date' ||
    key == 'joined_date' ||
    key == 'examination_date';

/// Text field that opens a calendar to pick a date (stored as YYYY-MM-DD).
class DatePickerField extends StatelessWidget {
  const DatePickerField({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
    this.firstDate,
    this.lastDate,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: AppDateFormats.parseStorage(controller.text) ?? today,
      firstDate: firstDate ?? DateTime(1950),
      lastDate: lastDate ?? DateTime(2100),
      helpText: 'Select $label',
      cancelText: 'Cancel',
      confirmText: 'Select',
    );
    if (picked != null) {
      controller.text = AppDateFormats.storage(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(context),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: 'Tap to choose a date',
        suffixIcon: IconButton(
          tooltip: 'Choose date',
          onPressed: () => _pickDate(context),
          icon: const Icon(Icons.calendar_month_outlined),
        ),
      ),
    );
  }
}

/// Sensible picker limits for known form date fields.
DatePickerField datePickerForKey({
  required String key,
  required TextEditingController controller,
  required String label,
}) {
  final today = DateTime.now();
  final endOfToday = DateTime(today.year, today.month, today.day);

  switch (key) {
    case 'date_of_birth':
      return DatePickerField(
        controller: controller,
        label: label,
        firstDate: DateTime(1950),
        lastDate: endOfToday,
      );
    case 'registered_date':
    case 'joined_date':
      return DatePickerField(
        controller: controller,
        label: label,
        required: true,
        firstDate: DateTime(2000),
        lastDate: endOfToday,
      );
    case 'examination_date':
      return DatePickerField(
        controller: controller,
        label: label,
        required: true,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
    default:
      return DatePickerField(
        controller: controller,
        label: label,
        firstDate: DateTime(1950),
        lastDate: DateTime(2100),
      );
  }
}

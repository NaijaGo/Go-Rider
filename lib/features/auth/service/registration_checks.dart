class RegistrationChecks {
  static String? field(
    String label,
    String value, {
    String password = '',
    String vehicle = '',
    DateTime? today,
  }) {
    final text = value.trim();
    if (label == 'Gender' || label == 'Preferred Delivery Zone') return null;
    if (label.contains('License Number') && vehicle == 'bicycle') return null;
    if (text.isEmpty) return 'Please enter ${label.toLowerCase()}';
    if (label == 'Full Name' && text.length < 2) return 'Enter your full name';
    if (label == 'Email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return 'Enter a valid email address';
    }
    if (label.contains('Phone') &&
        (!RegExp(r'^\+?[\d\s-]+$').hasMatch(text) ||
            text.replaceAll(RegExp(r'\D'), '').length < 10 ||
            text.replaceAll(RegExp(r'\D'), '').length > 15)) {
      return 'Enter a valid phone number including area code';
    }
    if (label == 'Password' && text.length < 6) {
      return 'Use at least 6 characters';
    }
    if (label == 'Confirm Password' && text != password) {
      return 'Passwords do not match';
    }
    if (label == 'Account Number' && !RegExp(r'^\d{10}$').hasMatch(text)) {
      return 'Enter a 10-digit account number';
    }
    if (label == 'Vehicle Type' &&
        !{'motorcycle', 'bicycle', 'car', 'scooter'}.contains(text)) {
      return 'Select a supported vehicle';
    }
    if (label == 'Date of Birth') {
      final date = DateTime.tryParse(text);
      final canonical = date == null
          ? ''
          : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (date == null ||
          text != canonical ||
          date.year < 1900 ||
          date.isAfter(today ?? DateTime.now())) {
        return 'Select a valid date of birth';
      }
    }
    return null;
  }
}

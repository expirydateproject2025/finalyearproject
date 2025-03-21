class CustomDateUtils {
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static bool isValidDateFormat(String input) {
    // Basic date validation - can be enhanced based on needs
    RegExp dateRegex = RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$');
    return dateRegex.hasMatch(input);
  }
}
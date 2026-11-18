/// Form validators for merchant phone login and registration.
class Validators {
  Validators._();

  /// Normalizes Arabic numerals (٠-٩) to Western Arabic digits (0-9)
  static String normalizeNumbers(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = input.trim();
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], i.toString());
    }
    return result;
  }

  /// Validates Egyptian mobile phone numbers:
  /// Formats accepted:
  /// 010xxxxxxxx, 011xxxxxxxx, 012xxxxxxxx, 015xxxxxxxx
  /// +2010xxxxxxxx, 002010xxxxxxxx
  static String? validateEgyptianPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'من فضلك أدخل رقم الهاتف المحمول';
    }

    final normalized = normalizeNumbers(value).replaceAll(RegExp(r'[\s\-]'), '');
    final egRegex = RegExp(r'^(?:\+?20|0020)?0?1[0125]\d{8}$');

    if (!egRegex.hasMatch(normalized)) {
      return 'رقم هاتف غير صحيح. يجب أن يبدأ بـ 010، 011، 012، أو 015 (11 رقم)';
    }

    return null;
  }

  /// Validates merchant or owner full name
  static String? validateMerchantName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'من فضلك أدخل اسم التاجر أو المسؤول بالكامل';
    }

    if (value.trim().length < 3) {
      return 'الاسم يجب ألا يقل عن 3 أحرف';
    }

    return null;
  }

  /// Validates store / supermarket / kiosk name
  static String? validateStoreName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'من فضلك أدخل اسم المحل أو السوبر ماركت';
    }

    if (value.trim().length < 2) {
      return 'اسم المتجر يجب ألا يقل عن حرفين';
    }

    return null;
  }

  /// Validates store street address
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'من فضلك أدخل العنوان بالتفصيل وأقرب علامة مميزة';
    }

    if (value.trim().length < 5) {
      return 'العنوان يجب أن يكون مفصلاً (5 أحرف على الأقل)';
    }

    return null;
  }
}

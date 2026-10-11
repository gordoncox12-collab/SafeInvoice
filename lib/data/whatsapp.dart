/// WhatsApp chat helpers. Digits only; South African 0xx numbers become 27xx.
String normalizeWhatsAppDigits(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0') && digits.length >= 9 && digits.length <= 11) {
    digits = '27${digits.substring(1)}';
  }
  return digits;
}

/// Build `https://wa.me/<digits>` for a customer WhatsApp/phone number.
String whatsappChatUrl(String raw) {
  final digits = normalizeWhatsAppDigits(raw);
  if (digits.isEmpty) {
    throw FormatException('Enter a WhatsApp or phone number first.');
  }
  if (digits.length < 8) {
    throw FormatException('That WhatsApp number is too short.');
  }
  return 'https://wa.me/$digits';
}

String? customerWhatsAppNumber(String? whatsapp, String? phone) {
  final preferred = (whatsapp == null || whatsapp.trim().isEmpty) ? phone : whatsapp;
  if (preferred == null || preferred.trim().isEmpty) return null;
  final digits = normalizeWhatsAppDigits(preferred);
  return digits.isEmpty ? null : preferred;
}

/// Money helpers for POS Assistant.
///
/// We currently store money as REAL in the database for simplicity.
/// All business logic should still go through these helpers so we can
/// later switch to integer cents without rewriting the whole app.
class Money {
  /// Format a double amount for display (e.g. 1250.5 → "KSh 1,250.50")
  static String format(
    double amount, {
    String symbol = 'KSh',
    int decimals = 2,
  }) {
    final fixed = amount.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final fraction = parts.length > 1 ? parts[1] : '00';
    return '$symbol $whole.$fraction';
  }

  /// Safe parse from user input ("1,250.50", "1250", "KSh 1250.5" etc.)
  static double parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '').trim();
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned) ?? 0;
  }

  /// Round to 2 decimal places (useful before writing to DB)
  static double round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}

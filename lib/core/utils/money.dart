/// Money helpers for KES-style amounts (2 decimal places).
class Money {
  Money._();

  static String format(num value, {String currency = 'KSh'}) {
    final v = round(value.toDouble());
    final neg = v < 0;
    final abs = neg ? -v : v;
    final whole = abs.truncate();
    final frac = ((abs - whole) * 100).round().clamp(0, 99);
    final wholeStr = _groupThousands(whole);
    final fracStr = frac.toString().padLeft(2, '0');
    final body = frac == 0 ? wholeStr : '$wholeStr.$fracStr';
    return neg ? '-$currency $body' : '$currency $body';
  }

  /// Safe parse from user input ("1,250.50", "1250", "KSh 1250.5", empty → 0).
  static double parse(String input) {
    var s = input.trim();
    if (s.isEmpty) return 0;
    s = s.replaceAll(RegExp(r'[^\d,.\-]'), '');
    s = s.replaceAll(',', '');
    if (s.isEmpty || s == '-' || s == '.' || s == '-.') return 0;
    final v = double.tryParse(s);
    if (v == null || v.isNaN || v.isInfinite) return 0;
    return round(v);
  }

  static double round(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    return double.parse(value.toStringAsFixed(2));
  }

  static String _groupThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

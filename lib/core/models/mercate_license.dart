import 'dart:convert';

class MercateLicense {
  const MercateLicense({
    required this.schemaVersion,
    required this.product,
    required this.businessId,
    required this.licenseId,
    required this.issuedAt,
    required this.expiresAt,
    required this.graceDays,
    this.maxDevices,
  });

  final int schemaVersion;
  final String product;
  final String businessId;
  final String licenseId;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int graceDays;
  final int? maxDevices;

  factory MercateLicense.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    final graceDays = json['graceDays'] ?? 0;
    final maxDevices = json['maxDevices'];
    if (schemaVersion != 1 ||
        json['product'] != 'mercate' ||
        json['businessId'] is! String ||
        (json['businessId'] as String).isEmpty ||
        json['licenseId'] is! String ||
        (json['licenseId'] as String).isEmpty ||
        graceDays is! int ||
        graceDays < 0 ||
        (maxDevices != null && (maxDevices is! int || maxDevices < 1))) {
      throw const FormatException('Unsupported or invalid Mercate licence.');
    }
    final issuedAt = DateTime.tryParse('${json['issuedAt'] ?? ''}');
    final expiresAt = DateTime.tryParse('${json['expiresAt'] ?? ''}');
    if (issuedAt == null || expiresAt == null || !expiresAt.isAfter(issuedAt)) {
      throw const FormatException('Invalid licence validity period.');
    }
    return MercateLicense(
      schemaVersion: schemaVersion,
      product: 'mercate',
      businessId: json['businessId'] as String,
      licenseId: json['licenseId'] as String,
      issuedAt: issuedAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
      graceDays: graceDays,
      maxDevices: maxDevices as int?,
    );
  }

  static MercateLicense decodePayload(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Licence payload must be a JSON object.');
    }
    return MercateLicense.fromJson(decoded);
  }
}

enum LicenseState { unactivated, notYetValid, active, gracePeriod, expired, invalid, clockRollback }

class LicenseEvaluation {
  const LicenseEvaluation({required this.state, this.license, this.message});
  final LicenseState state;
  final MercateLicense? license;
  final String? message;
  bool get permitsLicensedOperation =>
      state == LicenseState.active || state == LicenseState.gracePeriod;
}

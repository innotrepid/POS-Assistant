/// Lightweight EN / SW strings for Mercate UI (no codegen).
/// Expand keys as screens are localised.
class AppStrings {
  const AppStrings(this.code);

  /// 'en' or 'sw'
  final String code;

  bool get isSw => code == 'sw';

  String _t(String en, String sw) => isSw ? sw : en;

  // —— App / nav ——
  String get appName => 'Mercate';
  String get home => _t('Home', 'Nyumbani');
  String get sell => _t('Sell', 'Uza');
  String get stock => _t('Stock', 'Bidhaa');
  String get customers => _t('Customers', 'Wateja');
  String get suppliers => _t('Suppliers', 'Wasambazaji');
  String get reports => _t('Reports', 'Ripoti');
  String get settings => _t('Settings', 'Mipangilio');
  String get assistant => _t('Assistant', 'Msaidizi');
  String get notifications => _t('Notifications', 'Arifa');

  // —— Common actions ——
  String get save => _t('Save', 'Hifadhi');
  String get cancel => _t('Cancel', 'Ghairi');
  String get delete => _t('Delete', 'Futa');
  String get edit => _t('Edit', 'Hariri');
  String get add => _t('Add', 'Ongeza');
  String get refresh => _t('Refresh', 'Onyesha upya');
  String get search => _t('Search', 'Tafuta');
  String get confirm => _t('Confirm', 'Thibitisha');
  String get close => _t('Close', 'Funga');
  String get yes => _t('Yes', 'Ndiyo');
  String get no => _t('Hapana', 'Hapana');
  String get ok => _t('OK', 'Sawa');
  String get back => _t('Back', 'Rudi');
  String get loading => _t('Loading…', 'Inapakia…');
  String get error => _t('Something went wrong', 'Hitilafu imetokea');

  // —— Settings ——
  String get language => _t('Language', 'Lugha');
  String get languageEnglish => _t('English', 'Kiingereza');
  String get languageSwahili => _t('Kiswahili', 'Kiswahili');
  String get languageHint => _t(
        'App labels in English or Kiswahili',
        'Lebo za programu kwa Kiingereza au Kiswahili',
      );
  String get appearance => _t('Appearance', 'Muonekano');
  String get security => _t('Security', 'Usalama');
  String get backup => _t('Backup', 'Hifadhi nakala');
  String get businessProfile => _t('Business profile', 'Wasifu wa biashara');
  String get themeSystem => _t('System', 'Mfumo');
  String get themeLight => _t('Light', 'Angavu');
  String get themeDark => _t('Dark', 'Giza');

  // —— Home / sales ——
  String get todaySales => _t('Today\'s sales', 'Mauzo ya leo');
  String get cash => _t('Cash', 'Fedha taslimu');
  String get mpesa => _t('M-Pesa', 'M-Pesa');
  String get expenses => _t('Expenses', 'Matumizi');
  String get closeDay => _t('Close day', 'Funga siku');
  String get debtors => _t('Debtors', 'Wadeni');
  String get lowStock => _t('Low stock', 'Bidhaa zimepungua');

  // —— Stock ——
  String get addItem => _t('Add item', 'Ongeza bidhaa');
  String get boughtToday => _t('Bought today', 'Nimenunua leo');
  String get spoilage => _t('Spoilage', 'Hasara / kuoza');
  String get deleteProduct => _t('Delete product?', 'Futa bidhaa?');
  String get keepProduct => _t('Keep product', 'Weka bidhaa');
  String get yesDelete => _t('Yes, delete', 'Ndiyo, futa');

  // —— Customers / debt ——
  String get addCustomer => _t('Add customer', 'Ongeza mteja');
  String get whoOwes => _t('Who owes me', 'Nani anadeni');
  String get call => _t('Call', 'Piga simu');
  String get sms => _t('SMS', 'SMS');

  // —— Reports ——
  String get trends => _t('Trends', 'Mwenendo');
  String get thisWeek => _t('This week', 'Wiki hii');
  String get thisMonth => _t('This month', 'Mwezi huu');
  String get exportPdf => _t('Export PDF', 'Pakua PDF');
  String get exportExcel => _t('Export Excel', 'Pakua Excel');

  // —— Assistant hints ——
  String get askAssistant => _t(
        'Ask about sales, stock, or debt…',
        'Uliza kuhusu mauzo, bidhaa, au deni…',
      );
}

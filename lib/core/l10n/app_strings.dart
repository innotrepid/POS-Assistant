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
  String get no => _t('No', 'Hapana');
  String get ok => _t('OK', 'Sawa');
  String get back => _t('Back', 'Rudi');
  String get loading => _t('Loading…', 'Inapakia…');
  String get retry => _t('Retry', 'Jaribu tena');
  String get clear => _t('Clear', 'Futa yote');
  String get more => _t('More', 'Zaidi');
  String get name => _t('Name', 'Jina');
  String get phone => _t('Phone', 'Simu');
  String get amount => _t('Amount', 'Kiasi');
  String get noteOptional => _t('Note (optional)', 'Maelezo (si lazima)');
  String get category => _t('Category', 'Aina');
  String get reason => _t('Reason', 'Sababu');
  String get record => _t('Record', 'Rekodi');
  String get noData => _t('No data', 'Hakuna data');
  String get other => _t('Other', 'Nyingine');
  String get describe => _t('Describe', 'Eleza');

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

  // —— Home / dashboard ——
  String get today => _t('Today', 'Leo');
  String get todaySales => _t("Today's sales", 'Mauzo ya leo');
  String get sales => _t('Sales', 'Mauzo');
  String get salesHistory => _t('Sales history', 'Historia ya mauzo');
  String get cash => _t('Cash', 'Taslimu');
  String get mpesa => _t('M-Pesa', 'M-Pesa');
  String get expenses => _t('Expenses', 'Matumizi');
  String get recordExpense => _t('Record expense', 'Rekodi matumizi');
  String get closeDay => _t('Close day', 'Funga siku');
  String get endOfDay => _t('End of day', 'Mwisho wa siku');
  String get paidWith => _t('Paid with', 'Imelipwa kwa');
  String get spoilageToday => _t('Spoilage today', 'Hasara leo');
  String recordsCount(int n) =>
      _t('$n record${n == 1 ? '' : 's'}', 'Rekodi $n');

  // —— POS ——
  String get pos => _t('POS', 'Uza');
  String get searchProducts => _t('Search products', 'Tafuta bidhaa');
  String get pay => _t('Pay', 'Lipa');
  String get total => _t('TOTAL', 'JUMLA');
  String get cartEmpty => _t(
        'Cart is empty — tap products to add',
        'Kikapu ni tupu — gusa bidhaa kuongeza',
      );
  String get quickSale => _t('Quick sale', 'Uza haraka');
  String get addToCart => _t('Add to cart', 'Ongeza kikapuni');
  String get itemName => _t('Item name', 'Jina la bidhaa');
  String get price => _t('Price', 'Bei');
  String get quantity => _t('Quantity', 'Idadi');
  String get receipt => _t('Receipt', 'Risiti');
  String get history => _t('History', 'Historia');
  String get noProductsPos => _t(
        'No products. Add stock first, or use Quick sale.',
        'Hakuna bidhaa. Ongeza stock kwanza, au tumia Uza haraka.',
      );
  String get invalidQuickSale => _t(
        'Enter a valid name, price, and quantity',
        'Weka jina, bei, na idadi sahihi',
      );

  // —— Stock ——
  String get addItem => _t('Add item', 'Ongeza bidhaa');
  String get addProduct => _t('Add product', 'Ongeza bidhaa');
  String get boughtToday => _t('Bought today', 'Nimenunua leo');
  String get spoilage => _t('Spoilage', 'Hasara / kuoza');
  String get deleteProductTitle => _t('Delete this product?', 'Futa bidhaa hii?');
  String get keepProduct => _t('Keep product', 'Weka bidhaa');
  String get yesDelete => _t('Yes, delete', 'Ndiyo, futa');
  String get editProduct => _t('Edit product', 'Hariri bidhaa');
  String get sellingPrice => _t('Selling price', 'Bei ya kuuza');
  String get costOptional => _t('Cost (optional)', 'Gharama (si lazima)');
  String get unit => _t('Unit', 'Kipimo');
  String get unitCostOptional =>
      _t('Unit cost (optional)', 'Gharama kwa kipimo (si lazima)');
  String get openingQtyOptional =>
      _t('Opening quantity (optional)', 'Idadi ya kuanzia (si lazima)');
  String get receiveGoods => _t('Receive goods', 'Pokea bidhaa');
  String get fromSupplier => _t('From supplier', 'Kutoka kwa msambazaji');
  String get howStockArrived =>
      _t('How did the stock arrive?', 'Bidhaa zilifikaje?');
  String get loadStarter =>
      _t('Load starter catalogue', 'Pakia orodha ya kuanzia');
  String get addMissingStarter =>
      _t('Add any missing starter items', 'Ongeza bidhaa za kuanzia zinazokosekana');
  String get productUpdated => _t('Product updated', 'Bidhaa imesasishwa');
  String get noProductsYet => _t(
        'No products yet. Tap Add item, or load a starter list for mama mboga.',
        'Bado hakuna bidhaa. Gusa Ongeza bidhaa, au pakia orodha ya mama mboga.',
      );
  String productRemoved(String name) =>
      _t('$name removed', '$name imeondolewa');

  // —— Customers / debt ——
  String get addCustomer => _t('Add customer', 'Ongeza mteja');
  String get whoOwes => _t('Who owes you', 'Nani anadeni');
  String get debtors => _t('Debtors', 'Wadeni');
  String get call => _t('Call', 'Piga simu');
  String get sms => _t('SMS', 'SMS');
  String get phoneHint =>
      _t('Max 10 digits (e.g. 07XXXXXXXX)', 'Taraki 10 (mf. 07XXXXXXXX)');
  String get walletTooltip => _t(
        'Call, SMS, promises — open wallet',
        'Simu, SMS, ahadi — fungua deni',
      );
  String get totalOutstanding => _t('Total outstanding', 'Jumla ya deni');
  String get searchNamePhone =>
      _t('Search name or phone', 'Tafuta jina au simu');
  String get promiseToPay => _t('Promise to pay', 'Ahadi ya kulipa');
  String get setPromise => _t('Set promise', 'Weka ahadi');
  String get promisedDate => _t('Promised date', 'Tarehe ya ahadi');
  String get statementRepay => _t('Statement / repay', 'Taarifa / lipa');
  String get contactLog => _t('Contact log', 'Rekodi za mawasiliano');
  String get copyMessage => _t('Copy message', 'Nakili ujumbe');
  String get howDidItGo => _t('How did it go?', 'Iliendaje?');

  // —— Reports ——
  String get trends => _t('Trends', 'Mwenendo');
  String get thisWeek => _t('This week', 'Wiki hii');
  String get thisMonth => _t('This month', 'Mwezi huu');
  String get weekMonthGraphs =>
      _t('Week & month graphs', 'Chati za wiki na mwezi');
  String get weekMonthHint => _t(
        'See how sales move across the week and month',
        'Angalia mwenendo wa mauzo wiki na mwezi',
      );
  String get salesToday => _t('Sales today', 'Mauzo ya leo');
  String get topItemsToday =>
      _t('Top items sold today', 'Bidhaa zilizouzwa zaidi leo');
  String get stockOnHand => _t('Stock on hand', 'Bidhaa zilizopo');
  String get expensesByCategory =>
      _t('Expenses by category', 'Matumizi kwa aina');
  String get lowStock => _t('Low stock', 'Bidhaa zimepungua');
  String get whatYouOwe =>
      _t('What you owe suppliers', 'Unachodaiwa na wasambazaji');
  String get sharePdf => _t('Share PDF report', 'Shiriki ripoti ya PDF');
  String get shareExcel => _t('Share Excel', 'Shiriki Excel');
  String get previewPdf => _t('Preview PDF', 'Angalia PDF');
  String get noOpenBalances =>
      _t('No open balances', 'Hakuna deni lililo wazi');

  // —— Assistant ——
  String get mercateAssistant => _t('Mercate Assistant', 'Msaidizi wa Mercate');
  String get askAssistant => _t(
        'Ask about sales, stock, or debt…',
        'Uliza kuhusu mauzo, bidhaa, au deni…',
      );
  String get askOrRecordPayment => _t(
        'Ask or record a payment…',
        'Uliza au rekodi malipo…',
      );
  String get dailyBrief => _t('Daily brief', 'Muhtasari wa siku');
  String get openDialer => _t('Open dialer', 'Fungua simu');
  String get openSms => _t('Open SMS?', 'Fungua SMS?');
  String get openMessages => _t('Open Messages', 'Fungua ujumbe');
  String get noPhoneNumber => _t('No phone number', 'Hakuna nambari ya simu');
}

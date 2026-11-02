/// Lightweight EN / SW strings for Mercate UI (no codegen).
class AppStrings {
  const AppStrings(this.code);

  /// 'en' or 'sw'
  final String code;

  bool get isSw => code == 'sw';

  String _t(String en, String sw) => isSw ? sw : en;

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
  String get notesOptional => _t('Notes (optional)', 'Maelezo (si lazima)');
  String get category => _t('Category', 'Aina');
  String get reason => _t('Reason', 'Sababu');
  String get record => _t('Record', 'Rekodi');
  String get noData => _t('No data', 'Hakuna data');
  String get other => _t('Other', 'Nyingine');
  String get describe => _t('Describe', 'Eleza');
  String get skip => _t('Skip', 'Ruka');
  String get method => _t('Method', 'Njia');
  String get subtotal => _t('Subtotal', 'Jumla ndogo');
  String get remaining => _t('Remaining', 'Iliyobaki');
  String get selectCustomer => _t('Select customer', 'Chagua mteja');
  String get pleaseConfirm => _t('Please confirm', 'Tafadhali thibitisha');
  String get riskWarning => _t('Risk warning', 'Onyo');
  String get offlinePos => _t('Mercate · offline POS', 'Mercate · POS bila mtandao');

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

  String get today => _t('Today', 'Leo');
  String get todaySales => _t("Today's sales", 'Mauzo ya leo');
  String get sales => _t('Sales', 'Mauzo');
  String get salesHistory => _t('Sales history', 'Historia ya mauzo');
  String get cash => _t('Cash', 'Taslimu');
  String get mpesa => _t('M-Pesa', 'M-Pesa');
  String get card => _t('Card', 'Kadi');
  String get bank => _t('Bank', 'Benki');
  String get expenses => _t('Expenses', 'Matumizi');
  String get recordExpense => _t('Record expense', 'Rekodi matumizi');
  String get closeDay => _t('Close day', 'Funga siku');
  String get endOfDay => _t('End of day', 'Mwisho wa siku');
  String get paidWith => _t('Paid with', 'Imelipwa kwa');
  String get spoilageToday => _t('Spoilage today', 'Hasara leo');
  String recordsCount(int n) =>
      _t('$n record${n == 1 ? '' : 's'}', 'Rekodi $n');

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
  String get checkout => _t('Checkout', 'Malipo');
  String get reviewComplete => _t('Review & complete', 'Kagua na kamilisha');
  String get cashReceived => _t('Cash received', 'Taslimu iliyopokelewa');
  String get amountPaid => _t('Amount paid', 'Kiasi kilicholipwa');
  String get amountPaidNowOptional =>
      _t('Amount paid now (optional)', 'Kiasi kilicholipwa sasa (si lazima)');
  String get saleDiscount => _t('Sale discount (amount)', 'Punguzo la mauzo');
  String get splitPayment => _t('Split payment', 'Gawanya malipo');
  String get splitPayments => _t('Split payments:', 'Malipo yaliyogawanywa:');
  String get addPaymentLeg => _t('Add payment leg', 'Ongeza njia ya malipo');
  String get creditDebtSale => _t('Credit / debt sale', 'Mauzo ya mkopo / deni');
  String get unpaidBecomesDebt => _t(
        'Unpaid balance will be recorded as debt.',
        'Salio lisilolipwa litarekodiwa kama deni.',
      );
  String get restBecomesDebt => _t(
        'Rest becomes customer debt',
        'Salio litakuwa deni la mteja',
      );
  String get changeAuto => _t(
        'Change is calculated automatically',
        'Chenji inahesabiwa moja kwa moja',
      );
  String get mpesaRefRequired =>
      _t('M-Pesa reference (required)', 'Rejea ya M-Pesa (lazima)');
  String get cardRefOptional =>
      _t('Card reference (optional)', 'Rejea ya kadi (si lazima)');
  String get bankRefRequired =>
      _t('Bank reference (required)', 'Rejea ya benki (lazima)');
  String get referenceOptional =>
      _t('Reference (optional)', 'Rejea (si lazima)');
  String get referenceRequired =>
      _t('Reference (required)', 'Rejea (lazima)');
  String get selectCustomerCredit => _t(
        'Select a customer for credit / remaining balance.',
        'Chagua mteja kwa mkopo / salio.',
      );
  String get confirmAdjustment => _t(
        'Confirm you understand this adjustment.',
        'Thibitisha unaelewa marekebisho haya.',
      );
  String get duplicateReference =>
      _t('Duplicate reference', 'Rejea imerudiwa');

  String get addItem => _t('Add item', 'Ongeza bidhaa');
  String get addProduct => _t('Add product', 'Ongeza bidhaa');
  String get boughtToday => _t('Bought today', 'Nimenunua leo');
  String get spoilage => _t('Spoilage', 'Hasara / kuoza');
  String get deleteProductTitle =>
      _t('Delete this product?', 'Futa bidhaa hii?');
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
  String get starterAllPresent => _t(
        'All starter items are already in stock.',
        'Bidhaa zote za kuanzia tayari zipo.',
      );
  String starterAdded(int n) =>
      _t('Added $n new starter products.', 'Imeongezwa bidhaa $n za kuanzia.');

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
  String get showAll => _t('Show all', 'Onyesha zote');
  String get overdueOnly => _t('Overdue only', 'Zilizochelewa tu');
  String get noCallsLogged => _t(
        'No calls or SMS logged yet.',
        'Bado hakuna simu wala SMS zilizorekodiwa.',
      );
  String get logCallHint => _t(
        'Log the call so you remember next time.',
        'Rekodi simu ili ukumbuke baadaye.',
      );
  String get logSmsHint =>
      _t('Log the SMS outcome.', 'Rekodi matokeo ya SMS.');
  String get couldNotOpenDialer =>
      _t('Could not open dialer', 'Haikuweza kufungua simu');

  String get outcomeNoAnswer => _t('No answer', 'Hakujibu');
  String get outcomeUnreachable => _t('Unreachable', 'Haipatikani');
  String get outcomeBusy => _t('Busy', 'Inatumika');
  String get outcomeSpoke => _t('Spoke', 'Walizungumza');
  String get outcomePromisedTomorrow =>
      _t('Promised tomorrow', 'Ameahidi kesho');
  String get outcomePromisedFriday =>
      _t('Promised Friday', 'Ameahidi Ijumaa');
  String get outcomeWillPayLater =>
      _t('Will pay later', 'Atatoa baadaye');
  String get outcomePaidPartial =>
      _t('Paid partial', 'Amelipa sehemu');
  String get outcomeWrongNumber =>
      _t('Wrong number', 'Nambari si sahihi');
  String get skipLog => _t('Skip log', 'Ruka rekodi');

  String get trends => _t('Trends', 'Mwenendo');
  String get thisWeek => _t('This week', 'Wiki hii');
  String get thisMonth => _t('This month', 'Mwezi huu');
  String get week => _t('Week', 'Wiki');
  String get month => _t('Month', 'Mwezi');
  String get weekMonthGraphs =>
      _t('Week & month graphs', 'Chati za wiki na mwezi');
  String get weekMonthHint => _t(
        'See how sales move across the week and month',
        'Angalia mwenendo wa mauzo wiki na mwezi',
      );
  String get salesToday => _t('Sales today', 'Mauzo ya leo');
  String get salesTotal => _t('Sales total', 'Jumla ya mauzo');
  String get salesCount => _t('Sales count', 'Idadi ya mauzo');
  String get topItemsToday =>
      _t('Top items sold today', 'Bidhaa zilizouzwa zaidi leo');
  String get topItemsSold => _t('Top items sold', 'Bidhaa zilizouzwa zaidi');
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
  String get dayTotals => _t('Day totals', 'Jumla ya siku');
  String get salesByHour => _t('Sales by hour', 'Mauzo kwa saa');
  String get salesByDay => _t('Sales by day', 'Mauzo kwa siku');
  String get dayByDay => _t('Day by day', 'Siku kwa siku');
  String get tillCount => _t('Till count', 'Hesabu ya til');
  String get openingCash => _t('Opening cash in till', 'Taslimu ya kuanzia');
  String get openingCashHint => _t(
        'What was in the till this morning',
        'Taslimu iliyokuwa til asubuhi',
      );
  String get countedCashNow => _t('Counted cash now', 'Taslimu uliyohesabu');
  String get newCredit => _t('New credit (deni)', 'Mkopo mpya (deni)');
  String get otherPaid => _t('Other paid', 'Nyingine zilizolipwa');
  String get estCostGoods =>
      _t('Est. cost of goods', 'Makadirio ya gharama ya bidhaa');
  String get estGrossProfit =>
      _t('Est. gross profit', 'Makadirio ya faida');
  String get reviewThenPin => _t(
        'Review the day, then confirm with PIN',
        'Kagua siku, kisha thibitisha kwa PIN',
      );
  String get confirmCloseWithPin =>
      _t('Confirm close with PIN', 'Thibitisha kufunga kwa PIN');
  String get closingBusy => _t('Closing…', 'Inafunga…');
  String get dayClosed => _t('Day closed', 'Siku imefungwa');
  String get alreadyClosed =>
      _t('Already closed — report only', 'Tayari imefungwa — ripoti tu');
  String get thisDayAlreadyClosed =>
      _t('This day is already closed', 'Siku hii tayari imefungwa');
  String get pinToCloseDay => _t('PIN to close day', 'PIN kufunga siku');
  String get noPinSet => _t('No PIN set', 'PIN haijawekwa');
  String get noCompletedSalesToday => _t(
        'No completed sales yet today.',
        'Bado hakuna mauzo yaliyokamilika leo.',
      );
  String get noSalesThisPeriod => _t(
        'No completed sales in this period yet.',
        'Bado hakuna mauzo yaliyokamilika kipindi hiki.',
      );
  String get barsHint => _t(
        'Bars show daily sales. Long-press a bar for the amount.',
        'Chati inaonyesha mauzo ya kila siku. Bonyeza kwa muda kuona kiasi.',
      );
  String get mpesaFromSales => _t(
        'M-Pesa is taken from sales (system tracked).',
        'M-Pesa inachukuliwa kutoka mauzo (mfumo unajua).',
      );

  String get mercateAssistant =>
      _t('Mercate Assistant', 'Msaidizi wa Mercate');
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
  String get howDidIDo => _t('How did I do today?', 'Nimefanyaje leo?');
  String get writesNeedConfirm => _t(
        'Writes only happen after you Confirm.',
        'Mabadiliko yataandikwa baada ya kuthibitisha.',
      );
  String get callNotUntilDialer => _t(
        'Call is not placed until you press Call in the dialer.',
        'Simu haitapigwa hadi ubonyeze Piga kwenye programu ya simu.',
      );
  String get smsNotUntilSend => _t(
        'Nothing is sent until you press Send in Messages.',
        'Ujumbe hautatumwa hadi ubonyeze Tuma kwenye Ujumbe.',
      );

  String get asstNoOneOwes =>
      _t('No one owes you right now.', 'Hakuna anayedaiwa sasa.');
  String get asstNoLowStock =>
      _t('No low-stock items right now.', 'Hakuna bidhaa zilizopungua sasa.');
  String get asstBasedOnToday =>
      _t('Based on today only.', 'Kulingana na leo tu.');
  String get asstAfterFewSales => _t(
        'After a few sales, ask again for busy hours.',
        'Baada ya mauzo machache, uliza tena saa za shughuli.',
      );
  String get asstBusyHours => _t('Busy hours', 'Saa za shughuli');
  String get asstMoneyNeedsConfirm => _t(
        'Money changes always need Confirm.',
        'Mabadiliko ya fedha yanahitaji Thibitisha.',
      );
}

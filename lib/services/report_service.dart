import '../core/database/app_database.dart';
import '../core/utils/money.dart';
import 'expense_service.dart';

class DaySalesReport {
  final String businessDate;
  final int saleCount;
  final double salesTotal;
  final double paidTotal;
  final double creditTotal;
  final double cash;
  final double mpesa;
  final double card;
  final double other;
  final double expensesTotal;
  final double estimatedCost;
  final double grossProfit;

  const DaySalesReport({
    required this.businessDate,
    required this.saleCount,
    required this.salesTotal,
    required this.paidTotal,
    required this.creditTotal,
    required this.cash,
    required this.mpesa,
    required this.card,
    required this.other,
    required this.expensesTotal,
    required this.estimatedCost,
    required this.grossProfit,
  });
}

class StockRow {
  final String productId;
  final String name;
  final double quantity;
  final double? costPrice;
  final double sellingPrice;

  const StockRow({
    required this.productId,
    required this.name,
    required this.quantity,
    this.costPrice,
    required this.sellingPrice,
  });

  double get stockValue =>
      Money.round(quantity * (costPrice ?? 0));
}

class PartyBalanceRow {
  final String id;
  final String name;
  final String? phone;
  final double balance;

  const PartyBalanceRow({
    required this.id,
    required this.name,
    this.phone,
    required this.balance,
  });
}

class ReportService {
  ReportService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<DaySalesReport> daySales([DateTime? day]) async {
    final d = day ?? DateTime.now();
    final range = DayRange.of(d);
    final db = await _database.database;

    final sales = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS sale_count,
        COALESCE(SUM(total), 0) AS sales_total,
        COALESCE(SUM(paid_amount), 0) AS paid_total,
        COALESCE(SUM(balance), 0) AS credit_total
      FROM sales
      WHERE sale_status = 'completed'
        AND created_at >= ? AND created_at < ?
      ''',
      [range.startIso, range.endIso],
    );

    final pay = await db.rawQuery(
      '''
      SELECT payment_type, COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE sale_id IS NOT NULL
        AND created_at >= ? AND created_at < ?
      GROUP BY payment_type
      ''',
      [range.startIso, range.endIso],
    );

    double cash = 0, mpesa = 0, card = 0, other = 0;
    for (final row in pay) {
      final type = (row['payment_type'] as String?)?.toLowerCase() ?? '';
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      switch (type) {
        case 'cash':
          cash = total;
          break;
        case 'mpesa':
          mpesa = total;
          break;
        case 'card':
          card = total;
          break;
        default:
          other += total;
      }
    }

    final costRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(si.quantity * COALESCE(si.unit_cost, 0)), 0) AS cost
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.sale_status = 'completed'
        AND s.created_at >= ? AND s.created_at < ?
      ''',
      [range.startIso, range.endIso],
    );

    final expenseRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE created_at >= ? AND created_at < ?
      ''',
      [range.startIso, range.endIso],
    );

    final salesTotal =
        Money.round((sales.first['sales_total'] as num?)?.toDouble() ?? 0);
    final estimatedCost =
        Money.round((costRows.first['cost'] as num?)?.toDouble() ?? 0);
    final expensesTotal =
        Money.round((expenseRows.first['total'] as num?)?.toDouble() ?? 0);

    return DaySalesReport(
      businessDate: range.businessDate,
      saleCount: (sales.first['sale_count'] as int?) ?? 0,
      salesTotal: salesTotal,
      paidTotal:
          Money.round((sales.first['paid_total'] as num?)?.toDouble() ?? 0),
      creditTotal:
          Money.round((sales.first['credit_total'] as num?)?.toDouble() ?? 0),
      cash: Money.round(cash),
      mpesa: Money.round(mpesa),
      card: Money.round(card),
      other: Money.round(other),
      expensesTotal: expensesTotal,
      estimatedCost: estimatedCost,
      grossProfit: Money.round(salesTotal - estimatedCost),
    );
  }

  Future<List<StockRow>> stockOnHand() async {
    final db = await _database.database;
    final products = await db.query(
      'products',
      where: 'active = 1',
      orderBy: 'name ASC',
    );

    final rows = <StockRow>[];
    for (final p in products) {
      final id = p['id'] as String;
      final stock = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(quantity), 0) AS qty
        FROM stock_movements
        WHERE product_id = ?
        ''',
        [id],
      );
      rows.add(
        StockRow(
          productId: id,
          name: p['name'] as String,
          quantity: (stock.first['qty'] as num?)?.toDouble() ?? 0,
          costPrice: (p['cost_price'] as num?)?.toDouble(),
          sellingPrice: (p['selling_price'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return rows;
  }

  Future<List<PartyBalanceRow>> debtorsOutstanding() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT c.id, c.name, c.phone,
             COALESCE(SUM(d.amount), 0) AS balance
      FROM customers c
      INNER JOIN debtor_transactions d ON d.customer_id = c.id
      GROUP BY c.id
      HAVING balance > 0.001
      ORDER BY balance DESC
      ''',
    );
    return rows
        .map(
          (r) => PartyBalanceRow(
            id: r['id'] as String,
            name: r['name'] as String,
            phone: r['phone'] as String?,
            balance: Money.round((r['balance'] as num?)?.toDouble() ?? 0),
          ),
        )
        .toList();
  }

  Future<List<PartyBalanceRow>> creditorsOutstanding() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT s.id, s.name, s.phone,
             COALESCE(SUM(c.amount), 0) AS balance
      FROM suppliers s
      INNER JOIN creditor_transactions c ON c.supplier_id = s.id
      GROUP BY s.id
      HAVING balance > 0.001
      ORDER BY balance DESC
      ''',
    );
    return rows
        .map(
          (r) => PartyBalanceRow(
            id: r['id'] as String,
            name: r['name'] as String,
            phone: r['phone'] as String?,
            balance: Money.round((r['balance'] as num?)?.toDouble() ?? 0),
          ),
        )
        .toList();
  }
}

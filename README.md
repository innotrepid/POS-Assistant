# POS-Assistant

Offline-first **business companion** for small shops: sales (POS), inventory, debtors, creditors, reports, and a local assistant.

> Target user: a shop owner who currently uses a notebook, calculator, or memory for sales, stock, and credit.

## Status (`foundation` branch)

| Layer | Status |
|-------|--------|
| SQLite schema + `AppDatabase` | Done |
| Product model + money helpers | Done |
| Inventory service (CRUD, stock ledger, WAC) | Done |
| Sales service (transactional sale, stock, payments, debtors, audit) | Done |
| Service tests (in-memory DB via `sqflite_common_ffi`) | Done |
| **POS engine** (search, cart, pay, receipt, history) | **In progress** |
| Inventory UI (add product / add stock) | Started |
| Debtors / creditors UI | Not started |
| Reports + PDF | Not started |
| Offline assistant | Not started |

## Getting started

### Prerequisites

- Flutter SDK 3.0+
- Dart SDK

### Setup

```bash
git clone https://github.com/innotrepid/POS-Assistant.git
cd POS-Assistant
git checkout foundation
flutter pub get
flutter run
```

On a machine without mobile tooling yet, you can still validate:

```bash
flutter analyze
flutter test
```

## How to try the POS flow

1. Open the **Stock** tab → tap **+** → add a product (name, selling price, optional cost + opening stock).
2. Open the **POS** tab → search or tap products into the cart.
3. Tap **Pay** → choose **cash / mpesa / card / credit** → complete sale.
4. Use the history icon for **sales history** and **receipt** view.

Credit sales need a customer ID for now (picker comes with the Debtors module).

## Project structure

```
lib/
├── core/
│   ├── database/app_database.dart   # SQLite schema + in-memory factory for tests
│   ├── models/product.dart
│   └── utils/money.dart
├── services/
│   ├── inventory_service.dart
│   └── sales_service.dart
├── features/
│   ├── pos/
│   │   ├── cart_line.dart
│   │   ├── cart_controller.dart
│   │   ├── pos_page.dart
│   │   ├── checkout_sheet.dart
│   │   ├── receipt_page.dart
│   │   └── sales_history_page.dart
│   ├── inventory/inventory_page.dart
│   ├── dashboard/ …
│   ├── customers/ …
│   ├── suppliers/ …
│   ├── reports/ …
│   ├── assistant/ …
│   └── settings/ …
└── main.dart
```

## Design principles

- **Offline-first** — local SQLite is the source of truth.
- **Every activity creates a record** — sales write stock movements, payments, debtor rows, and audit logs in one transaction.
- **Stock is a ledger** — quantity is `SUM(stock_movements)`, not a single mutable field.
- **Explainable money** — amounts go through `Money.round` / `Money.format`.

## Continuous integration

GitHub Actions on `main` and `foundation`:

- `flutter pub get`
- `dart format` (advisory)
- `flutter analyze --fatal-infos`
- `flutter test --coverage`

Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

## Roadmap (short)

1. ~~Foundation services + tests~~
2. **POS engine** ← current
3. Debtors / creditors
4. Reporting + PDF
5. Offline business assistant (rule-based first)

## License

Private / unreleased — see repository owner for terms.

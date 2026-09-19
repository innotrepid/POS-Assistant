# POS-Assistant

Offline-first **business companion** for small shops: sales (POS), inventory, debtors, creditors, reports, and a local assistant.

> Target user: a shop owner who currently uses a notebook, calculator, or memory for sales, stock, and credit.

## Status (`foundation` branch)

| Layer | Status |
|-------|--------|
| SQLite schema + services | Done |
| Inventory + Sales (transactional) | Done |
| Service tests | Done |
| POS: search, cart, pay, receipt, history | Done |
| Quick sale (no stock impact) | Done |
| Customer picker + Customers tab | Done |
| Inventory UI | Done |
| **Release APK via GitHub Actions** | **Done** |
| Debtors / creditors full module | Next |
| Reports + PDF | Later |
| Offline assistant | Later |

## Install on your phone (no Android Studio)

1. Open **Actions** → workflow **Build APK**.
2. Wait for the run to finish (or trigger **Run workflow** manually).
3. Open the run → **Artifacts** → download **`pos-assistant-apk`**.
4. Unzip → copy `app-release.apk` to your phone.
5. Install (allow “unknown sources” if prompted).

The APK is built on every push to `foundation` that changes `lib/` or `pubspec.yaml`, and on manual dispatch.

> First install: the APK is **unsigned debug-style release** for testing. Later we can add a signing key for Play Store.

## Getting started (developers)

```bash
git clone https://github.com/innotrepid/POS-Assistant.git
cd POS-Assistant
git checkout foundation
flutter create . --platforms=android   # once, if android/ is missing
flutter pub get
flutter run
```

```bash
flutter analyze
flutter test
```

## How to try POS on device

1. **Stock** → **+** → add product + opening stock  
2. **Customers** → **+** → add a customer (for credit sales)  
3. **POS** → add catalogue items, or tap the **flash** icon for **quick sale**  
4. **Pay** → cash / M-Pesa / card / credit → pick customer if needed  
5. History icon → receipt  

**Quick sale** never changes inventory (name is marked “(quick sale)” on the receipt).

## Project structure

```
lib/
├── core/database|models|utils
├── services/   inventory · sales · customer
├── features/
│   ├── pos/        cart, checkout, picker, receipt, history
│   ├── inventory/
│   └── customers/
└── main.dart
```

## CI

| Workflow | Purpose |
|----------|---------|
| [ci.yml](.github/workflows/ci.yml) | analyze + test |
| [build-apk.yml](.github/workflows/build-apk.yml) | release APK artifact |

## Roadmap

1. ~~Foundation services + POS engine~~
2. Debtors repayments + statements
3. Creditors / purchases
4. Reports + PDF
5. Offline assistant (rule-based)

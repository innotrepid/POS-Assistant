# POS-Assistant

Offline-first **business companion** for small shops: sales (POS), inventory, debtors, creditors, reports, and a local assistant.

> Target user: a shop owner who currently uses a notebook, calculator, or memory for sales, stock, and credit.

## Status (`foundation` branch)

| Layer | Status |
|-------|--------|
| SQLite schema + services | Done |
| Inventory + Sales (transactional) | Done |
| POS engine + quick sale | Done |
| Customers + picker | Done |
| **Debtors** (balance, repay, statement) | **Done** |
| APK via GitHub Actions | Done |
| Creditors / purchases | Next |
| Reports + PDF | Later |
| Offline assistant | Later |

## Install on your phone (no Android Studio)

1. Open **Actions** → workflow **Build APK**.
2. Wait for the run to finish (or trigger **Run workflow** manually).
3. Open the run → **Artifacts** → download **`pos-assistant-apk`**.
4. Unzip → copy `app-release.apk` to your phone.
5. Install (allow “unknown sources” if prompted).

## Try debtors on device

1. **POS** → sell on **credit** to a customer (creates debt).
2. **Customers** → see “Owes …” on the list, or open the **wallet** icon for **Debtors**.
3. Tap a customer → **statement** (credit sales + repayments).
4. Tap **Repay** → cash / M-Pesa / card (cannot overpay).
5. Balance and open sales update (FIFO against oldest unpaid sales).

## How to try POS

1. **Stock** → add product + opening stock  
2. **Customers** → add a customer  
3. **POS** → catalogue or **quick sale** (flash icon) → **Pay**  
4. History → receipt  

## Roadmap

1. ~~Foundation + POS~~
2. ~~Debtors~~
3. Creditors / purchases
4. Expenses + daily closing
5. Reports + PDF
6. Offline assistant
7. Business profiles (duka → mama mboga → …)

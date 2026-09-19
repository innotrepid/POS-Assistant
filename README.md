# POS-Assistant

Offline-first **business companion** for small shops.

## Status (`foundation`)

| Module | Status |
|--------|--------|
| POS + inventory + quick sale | Done |
| Customers + debtors (repay / statement) | Done |
| **Suppliers + purchases + creditors** | **Done** |
| APK via GitHub Actions | Done |
| Expenses + daily closing | Next |
| Reports + PDF | Later |
| Offline assistant | Later |
| Business profiles | Later |

## Phone install

**Actions → Build APK** → artifact `pos-assistant-apk` → install `app-release.apk`.

## Test creditors / purchases

1. **Stock** → add products  
2. **Suppliers** → **+** add supplier  
3. Inbox icon **Receive goods** → supplier, lines (qty + unit cost), amount paid (0 = full credit)  
4. Confirm → stock increases; if unpaid, supplier shows “We owe …”  
5. Open supplier → **Pay** (partial/full)  
6. Balance icon → **Creditors** list  

## Test debtors (existing)

POS credit sale → Customers / Debtors → Repay.

## Roadmap

1. ~~POS + debtors~~  
2. ~~Creditors + purchases~~  
3. Expenses + daily closing  
4. Reports + PDF  
5. Offline assistant  
6. Business profiles (duka, mama mboga, …)  

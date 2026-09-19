# POS-Assistant

Offline-first business companion for small shops.

## Status (`foundation`)

| Module | Status |
|--------|--------|
| POS + inventory + quick sale | Done |
| Customers + debtors | Done |
| Suppliers + purchases + creditors | Done |
| **Expenses + daily closing** | **Done** |
| APK via GitHub Actions | Done |
| Reports + PDF | Next |
| Offline assistant | Later |
| Business profiles | Later |

## Phone install

**Actions → Build APK** → `pos-assistant-apk` → install `app-release.apk`.

> Schema v3 adds `day_closings`. Fresh install is fine; existing installs upgrade on open.

## Test expenses + close day

1. Make a few **POS** sales (cash / M-Pesa).  
2. **Home** → **Expense** → category + amount.  
3. Home shows today’s sales, cash/M-Pesa split, expenses.  
4. **Close day** → opening cash, counted cash, counted M-Pesa.  
5. Snackbar shows match or cash variance.  

## Full test checklist (when ready)

- [ ] Stock / products  
- [ ] POS cash + quick sale + credit  
- [ ] Debtors repay  
- [ ] Receive goods + pay supplier  
- [ ] Expense + close day  

## Roadmap

1. ~~POS, debtors, creditors~~  
2. ~~Expenses + closing~~  
3. Reports + PDF  
4. Offline assistant  
5. Business profiles  

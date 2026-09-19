# POS-Assistant

Offline-first business companion for small shops.

## Status (`foundation`)

| Module | Status |
|--------|--------|
| Trading (POS, stock, debtors, creditors) | Done |
| Expenses + day close | Done |
| Reports + PDF | Done |
| Offline assistant (FAB only) | Done |
| **Business profiles** | **Done** |

## UI notes

- **Assistant** = sparkle FAB on the **left** (not in bottom nav).
- **Expense** / **Add product** FABs stay on the **right** so they do not overlap.

## Business profiles

Home → storefront icon → **Shop profile**

| Profile | Defaults |
|---------|----------|
| Duka / general retail | unit `piece` (default) |
| Mama mboga / produce | unit `kg` |
| Mini-market | unit `piece` |
| Wholesale | unit `carton` |
| Hardware / clothing | unit `piece` |
| Pharmacy / restaurant | listed, disabled until later |

New products pick up unit / batch / expiry defaults from the active profile. Existing products are not rewritten.

## Phone install

**Actions → Build APK** → `pos-assistant-apk`.

# POS-Assistant

Offline-first business companion for small shops.

## Status (`foundation`)

| Module | Status |
|--------|--------|
| POS, stock, customers, suppliers | Done |
| Debtors / creditors | Done |
| Expenses + day close | Done |
| Reports + PDF | Done (Uint8List fix) |
| **Offline assistant** | **Done** |
| Business profiles | Next |

## PDF fix

APK build failed because `doc.save()` is `List<int>` while `printing` needs `Uint8List`. Builder now returns `Uint8List.fromList(...)`.

## Assistant

• **Floating sparkle button** on every tab (except Assistant itself)  
• **Assistant** bottom tab  
• Rule-based, offline — reads your SQLite data  

Examples: “What did I sell today?”, “Who owes me?”, “Low stock”, “Explain POS”, “How does this app work?”

## Phone install

**Actions → Build APK** → `pos-assistant-apk` → install `app-release.apk`.

## Roadmap

1. ~~Core + reports + assistant~~  
2. Business profiles (duka, mama mboga, mini-market, …)  

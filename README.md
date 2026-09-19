# POS-Assistant

Offline-first business companion for small shops.

## Security

**Home → gear (Settings & security)**

1. **Set PIN** (4+ digits)  
2. Turn on **Require unlock**  
3. Optional: **Prefer biometrics** (fingerprint / face)

When lock is on:
- App opens to **lock screen** (biometric or PIN)
- **Close day** and **Shop profile** ask for identity again

PIN is stored as SHA-256 hash in local settings (not plain text).

## Safety rules (wave 1)

- M-Pesa/bank need reference  
- No accidental credit without choosing Credit  
- Cash change calculation  
- Discount / below-cost / debt warnings  
- Notifications bell (in-app)  

## Install

**Actions → Build APK** → install artifact.

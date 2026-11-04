# Mercate licensing foundation

## Identity and migration

Each installation receives a permanent `business_id` UUID in the shared
`mercate_meta.db` settings table. Existing installations are backfilled on
startup after onboarding has already completed. The backfill does not modify
the profile-specific business databases, sales, products, stock, customers,
suppliers, or backup files.

The ID is retained when shop details or the active business profile change.
Because the meta database is included in Mercate backups, the identity is
preserved by existing backup/restore flows. A restored backup therefore
represents the same licensed business. A clean installation on another phone
will generate a different ID until it is linked to the existing business; for
now, restoring that business's backup is the supported way to carry its ID to
a second device. A dedicated business-link/device-enrolment flow belongs in
Phase 2 so it cannot accidentally merge unrelated local records.

Existing customers are **not automatically licensed**. They remain unactivated
until the operator issues and enters a licence code.

## Signed licence token

The offline token format is:

```text
base64url(UTF-8 JSON payload).base64url(Ed25519 signature)
```

The signature is calculated over the exact UTF-8 payload bytes. Payload fields:

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Currently `1` |
| `product` | Must be `mercate` |
| `businessId` | Permanent UUID from the business meta database |
| `licenseId` | Unique issuer-side licence identifier |
| `issuedAt` | ISO-8601 issue timestamp |
| `expiresAt` | ISO-8601 expiry timestamp |
| `graceDays` | Signed grace period, configurable per issued licence |
| `maxDevices` | Optional positive integer; omitted/null means unlimited |

Mercate verifies signatures with Ed25519 and an embedded public key. The
private key must exist only in the separate Mercate Key Manager. Never commit
a private key or put it in Mercate build arguments.

Configure the public key at build time:

```sh
flutter build apk --release --dart-define=MERCATE_LICENSE_PUBLIC_KEY=<BASE64URL_ED25519_PUBLIC_KEY>
```

A build without the public key can still run the current app, but signed-code
activation will report that the verification key is not configured. No
licensing enforcement is wired into sales or other operations in this phase.

## Device and time policy

The signed `maxDevices` claim carries the custom per-business device limit.
A missing value means unlimited. Device registration, transfer and enforcement
are later integration work; this phase defines the signed claim only. Until
device enrolment exists, the signed limit is data carried by the licence, not
an enforced count of registered phones.

The signed `graceDays` value lets the issuer select the grace period per
business. The evaluator distinguishes active, grace-period, expired, invalid,
unactivated and clock-rollback states.

The last trusted local UTC time is stored in the shared meta database. This
detects a significant backwards clock change on the same installation, but
cannot provide perfect anti-tamper guarantees on a fully offline device.
Restoring an old backup can also roll this timestamp backwards; a later phase
must account for this in the device/restore policy.

## Separation from app security

PIN and biometric locking remain in `SecurityService`. Subscription state is
handled by `LicenseService`; neither service replaces or modifies the other.

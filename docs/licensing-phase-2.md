# Mercate licensing — Phase 2 activation

This phase adds the in-app activation and renewal workflow. It is based on
`foundation`; the stale `main` branch is not used as a development base.

## Customer activation

1. Open Settings → Mercate licence.
2. Copy the Business ID and send it to the licence issuer.
3. The issuer generates a signed code for that exact Business ID, duration,
   grace policy and chosen device allowance.
4. Paste the signed code into Mercate and select Verify and activate.
5. Mercate checks the Ed25519 signature and business binding locally, then
   stores the signed token in the shared metadata database.

Renewal uses the same screen. A new valid token replaces the prior token;
existing business data is not changed.

## Existing customer rollout

Existing customers remain unactivated until the operator issues and enters a
code. Phase 2 deliberately does not force an activation gate or restrict
business operations: this avoids interrupting existing paying customers while
manual licence issuance is underway.

## Device policy boundary

The signed token carries the issuer-selected `maxDevices` value (or null for
unlimited). This phase displays the signed allowance, but does not claim to
register devices or enforce a fleet-wide count. That requires the separate Key
Manager/device enrolment workflow and a defined offline transfer/recovery
policy.

## Expiry boundary

The status page displays active, grace, expired, invalid, not-yet-valid and
clock-rollback states. This phase does not block sales or other operations on
expiry. A later enforcement phase must first provide a tested read-only mode
that preserves viewing, backup and export, and must not delete customer data.

## Build configuration

The app needs the issuer's Ed25519 public key at build time:

```sh
flutter build apk --release --dart-define=MERCATE_LICENSE_PUBLIC_KEY=<BASE64URL_ED25519_PUBLIC_KEY>
```

The private signing key must never be packaged in Mercate.

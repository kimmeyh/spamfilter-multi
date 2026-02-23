# ADR-0026: Application Identity and Package Naming

## Status

Accepted

## Date

2026-02-15 (proposed), 2026-02-23 (accepted)

## Context

The app currently uses the Flutter default development identity:
- **Application ID**: `com.example.spamfiltermobile` (in `build.gradle.kts`)
- **Namespace**: `com.example.spamfiltermobile`
- **App label**: `spamfilter_mobile` (in `AndroidManifest.xml`)
- **MSIX identity**: `SpamFilterMulti` (in `pubspec.yaml`)

Google Play Store requires a unique application ID that:
- Cannot start with `com.example` (reserved for development)
- Must be globally unique across all Play Store apps
- Cannot be changed after first publication (permanent identifier)
- Should follow reverse-domain naming convention (e.g., `com.company.appname`)

The application ID also affects:
- OAuth redirect URI scheme (currently tied to `com.googleusercontent.apps.[client-id]`, which is independent)
- Firebase project configuration (`google-services.json` references package name)
- Credential storage keys (flutter_secure_storage uses package name for isolation)
- MSIX identity on Windows
- Any future iOS/macOS bundle identifiers

The user-facing app name (`android:label`) appears on the home screen, in the app drawer, in the Play Store listing, and in system settings. It should be user-friendly, memorable, and accurately describe the app.

## Decision

**Option B: App-Specific Domain** with `myemailspamfilter.com`.

### Application Identity

| Property | Current (Development) | New (Production) |
|----------|----------------------|-----------------|
| **Domain** | None | `myemailspamfilter.com` |
| **Application ID** (Android) | `com.example.spamfiltermobile` | `com.myemailspamfilter` |
| **Namespace** (Android) | `com.example.spamfiltermobile` | `com.myemailspamfilter` |
| **App Label** (Android) | `spamfilter_mobile` | `MyEmailSpamFilter` |
| **MSIX Identity** (Windows) | `SpamFilterMulti` | `MyEmailSpamFilter` |
| **MSIX Display Name** (Windows) | `Spam Filter Multi` | `MyEmailSpamFilter` |
| **iOS Bundle ID** (future) | `com.example.spamFilterMobile` | `com.myemailspamfilter` |

### User-Facing Name

**MyEmailSpamFilter** (18 characters, under 30-char Play Store limit)

### Domain

**myemailspamfilter.com** -- available as of 2026-02-23 (WHOIS confirmed unregistered).

Domain will be used for:
- Reverse-domain application ID (`com.myemailspamfilter`)
- Google OAuth brand verification (Tier 1)
- Privacy policy hosting (required for Play Store)
- App website / Play Store developer profile link

### Rationale

- `.com` is the most universally recognized and trusted TLD
- "myemailspamfilter" contains strong SEO keywords ("email", "spam", "filter")
- App-specific domain keeps app identity separate from personal developer identity
- Domain cost is minimal (~$10-15/yr)
- Application ID `com.myemailspamfilter` follows standard reverse-domain convention
- "MyEmailSpamFilter" is descriptive, user-friendly, and exactly describes the app

### Key Points

- The OAuth redirect URI scheme is tied to the Google Cloud OAuth client ID, NOT the application ID, so changing the application ID does not break OAuth flows
- Firebase Console must be reconfigured for the new package name (download new `google-services.json`)
- flutter_secure_storage on Android uses the package name for keystore alias isolation
- Any existing debug installations will be treated as a different app after ID change
- Domain must be registered before starting brand verification (GP-4 Phase 3, when triggered)

## Alternatives Considered

| Option | Verdict | Reason |
|--------|---------|--------|
| `com.kimmeyh.spamfilter` (personal domain) | Rejected | Ties app permanently to personal identity |
| `app.myspamfilter` (`.app` TLD) | Rejected | `myspamfilter.com` was taken; `.com` is more universally trusted |
| `dev.harold.spamfilter` (no domain) | Rejected | Would need a domain eventually for brand verification and privacy policy |
| `myspamfilter.com` | Unavailable | Registered since 2003 by CSC Corporate Domains |
| `myspamfilter.app` | Available but not chosen | `.com` preferred for familiarity and SEO |

## Consequences

### Positive
- Professional, permanent application identity ready for Play Store
- Domain provides hosting for privacy policy, website, and brand verification
- SEO-friendly domain with natural search keywords
- Clean reverse-domain application ID

### Negative
- Requires domain registration (~$10-15/yr recurring cost)
- Renaming requires updating multiple config files, Firebase re-registration, and new `google-services.json`
- Existing debug installations on devices will need to be uninstalled and reinstalled

### Migration Impact
- **Android**: Update `applicationId`, `namespace` in `build.gradle.kts`; update `android:label` in `AndroidManifest.xml`
- **Windows**: Update `msix_config` in `pubspec.yaml` (identity_name, display_name, publisher_display_name)
- **Firebase**: Re-register Android app with new package name, download new `google-services.json`
- **Credentials**: Existing secure storage entries under old package name will be orphaned (users re-authenticate once)
- **OAuth**: No changes needed (redirect URI is independent of package name)
- **Database**: AppPaths directory changes on some platforms (data migration needed or clean start)

See feature **GP-1A** in `docs/ALL_SPRINTS_MASTER_PLAN.md` for the implementation task breakdown.

## References

- `mobile-app/android/app/build.gradle.kts` - Current `applicationId` and `namespace` (line 11, 28)
- `mobile-app/android/app/src/main/AndroidManifest.xml` - Current `android:label` (line 3)
- `mobile-app/pubspec.yaml` - MSIX configuration (lines 77-86)
- GP-1 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description and tasks
- [Android Application ID](https://developer.android.com/build/configure-app-module#set-application-id) - Google documentation

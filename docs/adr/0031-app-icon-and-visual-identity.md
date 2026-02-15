# ADR-0031: App Icon and Visual Identity

## Status

Proposed

## Date

2026-02-15

## Context

The app currently uses the default Flutter launcher icon (`ic_launcher.png`) across five density buckets (mdpi through xxxhdpi). There are no adaptive icons, no round icon variant, and no branded splash screen.

### Current State

- **Launcher icons**: Legacy `ic_launcher.png` in mipmap-hdpi through mipmap-xxxhdpi
- **Adaptive icons**: None (no `ic_launcher_foreground.xml`, no `ic_launcher_background.xml`)
- **Round icons**: None (no `ic_launcher_round`)
- **Splash screen**: White placeholder (default Flutter splash)
- **Play Store icon**: None (512x512 high-res icon not created)
- **Feature graphic**: None (1024x500 not created)
- **Windows icon**: Referenced in MSIX config as `assets\icons\app_icon.png`
- **App label**: `spamfilter_mobile` (development name, not user-friendly)

### Android Adaptive Icon Requirements

Android 8.0+ (API 26+) introduced adaptive icons with:
- **Foreground layer**: App-specific icon element (108x108 dp, with 72x72 dp safe zone)
- **Background layer**: Solid color or simple pattern
- **System mask**: Android applies device-specific shape (circle, squircle, rounded square, etc.)

Apps without adaptive icons appear with a white square background on modern Android devices, looking unprofessional.

### Play Store Requirements

| Asset | Specification | Required |
|-------|-------------|----------|
| App icon | 512 x 512 px, max 1024 KB | Yes |
| Feature graphic | 1024 x 500 px, JPG or 24-bit PNG | Yes |
| Phone screenshots | Min 2, 320-3840 px sides, 16:9 | Yes |
| Tablet screenshots | Same specs as phone | If tablet support claimed |

### Visual Identity Considerations

The app is an email spam filter. Common visual metaphors:
- Shield (protection/security)
- Filter/funnel (filtering concept)
- Email envelope with checkmark/X
- Spam can (spam metaphor)
- Magnifying glass (inspection/scanning)

The icon must work at all sizes (from 16px notification icon to 512px store listing) and be recognizable in both light and dark system themes.

## Decision

**TO BE DETERMINED** - This ADR captures the decision criteria. The decision will be made by the Product Owner.

### Options Under Consideration

#### Icon Generation Approach

##### Option A: flutter_launcher_icons Package
- Add `flutter_launcher_icons` dev dependency
- Configure in `pubspec.yaml` or `flutter_launcher_icons.yaml`
- Generates all density variants, adaptive icons, and round icons from a single source image
- Also generates iOS icons and web favicons

##### Option B: Manual Asset Creation
- Create all icon variants manually or with external design tool
- Place in appropriate Android resource directories
- More control over each variant
- More maintenance overhead

##### Option C: Professional Icon Design Service
- Commission professional icon design
- Receive all required variants and assets
- Highest quality, most expensive
- Includes feature graphic and splash screen design

#### Splash Screen Approach

##### Option A: Minimal Splash (App Icon on Solid Background)
- Display app icon centered on brand-colored background
- Clean, professional, fast
- Uses Android 12+ splash screen API

##### Option B: Branded Splash with Animation
- Custom animation or logo reveal
- More polished but more complex
- May slow perceived launch time

##### Option C: No Custom Splash (Default Flutter)
- Keep current white placeholder
- Fastest to market
- Least professional appearance

### Decision Criteria

1. **Professionalism**: Icon quality directly impacts install rate
2. **Recognition**: Icon must be identifiable at small sizes
3. **Consistency**: Same visual identity across Android, Windows, Play Store listing
4. **Color scheme**: Should complement Material Design 3 theme already in use
5. **Development effort**: Icon generation tool vs manual creation
6. **Cost**: Free (self-created) vs paid (professional design)
7. **Timeline**: How quickly are assets needed?

### Key Points

- Adaptive icons are critical for a professional appearance on Android 8+ devices
- The 512x512 Play Store icon is separate from the device launcher icon
- Feature graphic (1024x500) is the first thing users see in Play Store search results
- The `flutter_launcher_icons` package can generate all variants from a single source
- Screenshots must show real app UI (not mockups) per Play Store policy
- The current MSIX config references `assets\icons\app_icon.png` which should be the same or similar to the Android icon

## Alternatives Considered

Analysis deferred until decision criteria are evaluated by Product Owner.

## Consequences

To be documented after decision is made.

## References

- `mobile-app/android/app/src/main/res/mipmap-*/ic_launcher.png` - Current legacy icons
- `mobile-app/android/app/src/main/AndroidManifest.xml` - Icon reference (line 5)
- `mobile-app/pubspec.yaml` - MSIX logo path (line 83)
- GP-6 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Store listing assets
- GP-7 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Adaptive icons and branding
- [Adaptive icons (Android Developers)](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive)
- [flutter_launcher_icons package](https://pub.dev/packages/flutter_launcher_icons)

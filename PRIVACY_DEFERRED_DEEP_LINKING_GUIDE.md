# Privacy-Aware Deferred Deep Linking Guide

This guide covers the deferred deep linking features added to the LinkGravity Flutter SDK for iOS and Android.

## Overview

Deferred deep linking enables your app to open to a specific screen immediately after installation, matching the user's pre-install web click. This guide covers the privacy-first approach that doesn't require IDFA or GAID.

## Features

- ✅ **Privacy-First**: No IDFA, GAID, or IP tracking required
- ✅ **Probabilistic Matching**: Device fingerprint matching (timezone, locale, browser, time window)
- ✅ **Confidence Levels**: HIGH, MEDIUM, LOW, NONE
- ✅ **SKAdNetwork Support**: Apple's privacy-preserving attribution (iOS)
- ✅ **Private Relay Compatible**: Works with iCloud Private Relay
- ✅ **Mail Privacy Protection Compatible**: Handles MPP correctly

## Quick Start

### 1. Initialize LinkGravity SDK

```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize LinkGravity SDK
  await LinkGravityClient.initialize(
    baseUrl: 'https://api.linkgravity.io',
    apiKey: 'pk_test_...',
  );

  runApp(const MyApp());
}
```

### 2. Handle Deferred Deep Link in initState

```dart
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _handleDeferredDeepLink();
  }

  Future<void> _handleDeferredDeepLink() async {
    final deepLink = await LinkGravityClient.instance.handleDeferredDeepLink(
      onFound: () {
        print('🎉 Opening deferred deep link');
        // The SDK will automatically navigate based on the deep link
      },
      onNotFound: () {
        print('ℹ️ No deferred deep link - showing home screen');
      },
    );

    if (deepLink != null) {
      print('✅ Deep link: $deepLink');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkGravity Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}
```

### 3. Track Installation

```dart
// Track that user has installed the app
await LinkGravityClient.instance.trackInstall();

// Or with deferred link data (automatic if using handleDeferredDeepLink)
await LinkGravityClient.instance.trackInstall(
  deferredLinkId: 'link-123',
  matchConfidence: 'high',
  matchScore: 105.0,
);
```

### 4. Track Conversions

```dart
// When user completes a purchase or signup
await LinkGravityClient.instance.trackConversion(
  linkId: 'link-123',
  conversionType: 'purchase',
  revenue: 29.99,
  customData: {
    'product_id': '456',
    'category': 'electronics',
  },
);
```

## Models

### DeepLinkMatch

The result of matching a device fingerprint:

```dart
class DeepLinkMatch {
  final bool found;                    // Whether a match was found
  final String confidence;             // 'high', 'medium', 'low', 'none'
  final int score;                     // 0-130
  final String? deepLinkUrl;           // URL to open
  final String? linkId;                // Link identifier
  final DeepLinkMatchMetadata metadata; // Detailed match info

  bool isHighConfidence() => confidence == 'high';
  bool isAcceptableConfidence() => confidence == 'high' || confidence == 'medium';
}
```

### SDKFingerprint

Device attributes collected for matching:

```dart
class SDKFingerprint {
  final String platform;        // 'ios', 'android'
  final String? idfv;          // iOS Identifier for Vendor (optional)
  final String model;          // Device model
  final String osVersion;      // OS version
  final int timezone;          // Offset in minutes
  final String locale;         // e.g., 'en-US'
  final String userAgent;      // Browser/app user agent
  final String timestamp;      // ISO 8601 string
}
```

## Implementation Details

### Fingerprint Collection

The SDK automatically collects the following attributes:

| Attribute | iOS | Android | Web | Notes |
|-----------|-----|---------|-----|-------|
| Platform | ✅ | ✅ | ✅ | Device platform |
| IDFV | ✅ | ❌ | ❌ | iOS Identifier for Vendor (optional) |
| Model | ✅ | ✅ | ❌ | Device model |
| OS Version | ✅ | ✅ | ❌ | Operating system version |
| Timezone | ✅ | ✅ | ✅ | Timezone offset in minutes |
| Locale | ✅ | ✅ | ✅ | Device locale |
| User-Agent | ✅ | ✅ | ✅ | Browser/app identifier |

### Matching Algorithm

The backend uses probabilistic scoring:

**Required:**
- Platform (iOS/Android) - Must match exactly

**Weighted Scoring:**
- Timezone & Locale: +30-40 points
- Browser family: +10 points (fuzzy match)
- Time window (< 5 min): +25 points
- Device model: +5 points

**Confidence Levels:**
- HIGH (≥95): Direct deep link opening recommended
- MEDIUM (70-94): Acceptable, consider confirmation
- LOW (50-69): Weak match, home screen safer
- NONE (<50): No match, show home screen

### Privacy Features

**What's NOT collected:**
- ❌ IDFA (Identifier for Advertisers)
- ❌ GAID (Google Advertising ID)
- ❌ IP Address
- ❌ MAC Address
- ❌ IMEI
- ❌ Persistent device identifiers

**Private Relay Support:**
- Fingerprints work even with iCloud Private Relay
- Timezone and locale still available
- Fuzzy browser matching handles IP masking

**Mail Privacy Protection Support:**
- User-Agent preserved through Mail app
- Browser identification still works
- No additional setup required

## SKAdNetwork Integration

### Automatic Postback Request

The SDK automatically requests postback on first launch (iOS only):

```dart
// This is handled automatically by the SDK
// No additional code needed for basic postback
```

### Manual Control

For advanced use cases:

```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

// To manually request postback:
final client = LinkGravityClient.instance;

// SKAdNetwork will be requested automatically on next app launch
// You can force it if needed (advanced use only)
```

## Error Handling

The SDK handles errors gracefully:

```dart
try {
  final deepLink = await LinkGravityClient.instance.handleDeferredDeepLink(
    onFound: () => print('Found!'),
    onNotFound: () => print('Not found - showing home'),
  );
} catch (e) {
  print('Error: $e');
  // App continues to work, shows home screen
}
```

## Testing

### Test Web Fingerprints

To test deferred deep linking:

1. Click a link from your browser (desktop, not in-app)
2. Get redirected to App Store
3. Install app
4. Open app - SDK should detect and match the deferred deep link

### Test Different Confidence Levels

Confidence levels depend on matching attributes:

- **HIGH**: Same device, recent click (< 1 min), same timezone
- **MEDIUM**: Same device, older click (< 30 min), same locale
- **LOW**: Similar timezone/locale but not exact match
- **NONE**: No matching attributes found

### Mock Testing

For unit tests with mock data:

```dart
test('DeepLinkMatch parses JSON correctly', () {
  final json = {
    'found': true,
    'confidence': 'high',
    'score': 105,
    'deepLinkUrl': 'myapp://product/123',
    'linkId': 'link-123',
    'metadata': {
      'matchReasons': ['platform', 'timezone', 'time_window'],
      'platformMatch': true,
      'timezoneMatch': true,
      'localeMatch': false,
      'browserMatch': true,
      'timeWindow': 25,
    },
  };

  final match = DeepLinkMatch.fromJson(json);

  expect(match.found, isTrue);
  expect(match.confidence, 'high');
  expect(match.isAcceptableConfidence(), isTrue);
});
```

## Best Practices

### 1. Always Check Confidence Level

```dart
if (match.isAcceptableConfidence()) {
  // Safe to open deep link
  navigateToDeepLink(match.deepLinkUrl);
} else {
  // Show home screen for low confidence
  navigateToHome();
}
```

### 2. Track All Events

```dart
// On app launch
await LinkGravityClient.instance.trackInstall();

// On important user actions
await LinkGravityClient.instance.trackConversion(
  linkId: 'link-123',
  conversionType: 'purchase',
  revenue: totalPrice,
);
```

### 3. Handle Errors Gracefully

```dart
try {
  final deepLink = await LinkGravityClient.instance.handleDeferredDeepLink(
    onFound: () => print('Opening deep link'),
    onNotFound: () => print('Showing home screen'),
  );
} catch (e) {
  // Network error, SDK error, etc.
  // App continues to home screen
  LinkGravityLogger.error('Deep link error: $e');
}
```

### 4. Test on Real Devices

- Test on physical iOS and Android devices
- Test with various network conditions
- Test with different time zones
- Test with app installed and not installed

## Troubleshooting

### Deep link not matching

1. **Check timestamp**: Must be within ~5 minutes of web click
2. **Check timezone**: Device timezone should match click timezone
3. **Check platform**: iOS must match iOS, Android must match Android
4. **Check confidence**: Lower scores = weaker match

### Postback not received

1. **iOS only**: Postback is iOS-specific (SKAdNetwork)
2. **Wait for window**: Apple takes 24-100 hours
3. **Check app status**: App must be installed from App Store
4. **Verify bundle ID**: Must match your actual app

### SDK not initialized

```dart
// Make sure to initialize before use
await LinkGravityClient.initialize(
  baseUrl: 'https://api.linkgravity.io',
  apiKey: 'your-api-key',
);

// Then use
final link = await LinkGravityClient.instance.handleDeferredDeepLink(
  onFound: () => print('Found'),
  onNotFound: () => print('Not found'),
);
```

## Architecture

```
App Launch
    ↓
LinkGravityClient.initialize()
    ↓
initState() - handleDeferredDeepLink()
    ↓
DeferredDeepLinkService._gatherFingerprint()
    ↓
ApiService.matchLink()  → Backend /api/v1/sdk/match-link
    ↓
DeepLinkMatch received
    ↓
Check confidence level
    ↓
Open deep link or home screen
    ↓
trackInstall() → Backend records installation
    ↓
User completes action
    ↓
trackConversion() → Backend records conversion
```

## Performance Considerations

- **Fingerprint collection**: < 100ms
- **API call**: < 1-2 seconds (depends on network)
- **Total time**: Usually < 2 seconds
- **Timeout**: 30 seconds (configurable)

If matching takes too long, SDK will timeout and show home screen rather than blocking app load.

## Privacy Policy

Users should be informed that LinkGravity collects:
- Device timezone and locale
- Device model and OS version
- App usage data

Importantly, we do NOT collect:
- Device identifiers (IDFA, GAID, MAC, IMEI)
- IP addresses
- Personal information
- Location data

## Further Reading

- [iOS Deep Linking Guide](../iOS_SETUP_GUIDE.md)
- [Backend Architecture](../ARCHITECTURE-iOS-Privacy-Deferred-DEEPLINKS.md)
- [API Documentation](../QUICK_IMPLEMENTATION_REFERENCE.md)

## Support

For issues or questions:
1. Check this guide's Troubleshooting section
2. Review example app code
3. Check SDK logs: `LinkGravityLogger.setLevel(LogLevel.debug)`
4. File issue on GitHub: https://github.com/LeCause/linkgravity-sdk/issues
# LinkGravity Flutter SDK

[![Pub Version](https://img.shields.io/pub/v/linkgravity_flutter_sdk)](https://pub.dev/packages/linkgravity_flutter_sdk)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A comprehensive Flutter SDK for **deferred deep linking**, **link generation**, and **app-to-app attribution**. Fully compatible with **FlutterFlow**.

## Features

- Link Generation - Create LinkGravity links programmatically
- Deep Link Handling - Universal Links (iOS) & App Links (Android)
- Deferred Deep Linking - Attribution matching after app install
  - **Android**: Play Install Referrer API (100% deterministic matching)
  - **iOS**: Fingerprint matching (~85-90% probabilistic matching)
- Click Tracking & Analytics - Comprehensive event tracking
- App-to-App Attribution - Track user acquisition sources
- Offline Queue - Track events offline, sync when online
- Custom Event Tracking - Track any custom events
- FlutterFlow Compatible - Ready-to-use Custom Actions
- Privacy-Focused - Device fingerprinting without IDFA/GAID

## Requirements

- Dart SDK: `>=3.0.0 <4.0.0` (Compatible with Dart 3.8.1 for FlutterFlow)
- Flutter: `>=3.10.0`

## Installation

Add to your pubspec.yaml:

```yaml
dependencies:
  linkgravity_flutter_sdk: ^1.0.0
```

Then run: `flutter pub get`

## Quick Start

### Initialize the SDK

```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LinkGravityClient.initialize(
    baseUrl: 'https://api.linkgravity.io',
    apiKey: 'your-api-key',
  );

  runApp(MyApp());
}
```

### Create a Link

```dart
final link = await LinkGravityClient.instance.createLink(
  LinkParams(
    longUrl: 'https://example.com/product/123',
    title: 'Amazing Product',
    deepLinkConfig: DeepLinkConfig(
      deepLinkPath: '/product/123',
    ),
  ),
);

print('Short URL: ${link.shortUrl}');
```

### Handle Deep Links

```dart
LinkGravityClient.instance.onDeepLink.listen((deepLink) {
  print('Deep link opened: ${deepLink.path}');
  // Navigate based on deep link
});
```

### Track Events

```dart
await LinkGravityClient.instance.trackEvent('product_viewed', {
  'productId': '123',
});
```

### Track Conversions

```dart
await LinkGravityClient.instance.trackConversion(
  type: 'purchase',
  revenue: 29.99,
  currency: 'USD',
  linkId: 'optional-link-id',
);
```

## Deferred Deep Linking

The SDK automatically handles deferred deep linking on first app launch. It uses the best available method based on the platform:

### Android (100% Deterministic)

On Android, the SDK uses the **Play Install Referrer API** to retrieve the exact link that led to the install. This provides 100% accurate attribution.

The SDK automatically:
1. Retrieves the install referrer from Play Store
2. Extracts the `deferred_link` token
3. Queries the backend for the associated deep link
4. Falls back to fingerprint matching if referrer is unavailable

### iOS (Probabilistic)

On iOS, the SDK uses **fingerprint matching** to probabilistically match the user to the original click. This typically achieves 85-90% accuracy.

### Manual Deferred Deep Link Handling

If you need to handle deferred deep links manually:

```dart
final deepLinkUrl = await LinkGravityClient.instance.handleDeferredDeepLink(
  onFound: () {
    print('Deferred deep link found!');
  },
  onNotFound: () {
    print('No deferred deep link');
  },
);

if (deepLinkUrl != null) {
  // Navigate to the deep link URL
}
```

## Android Setup

### Play Install Referrer

The SDK automatically integrates with the Play Install Referrer API. No additional setup is required.

For the referrer to work, your LinkGravity links must include the `deferred_link` parameter in the Play Store URL. The LinkGravity backend handles this automatically when generating links.

### App Links

Add to your `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="your-domain.com"/>
</intent-filter>
```

## iOS Setup

### Universal Links

1. Add the Associated Domains capability in Xcode
2. Add your domain: `applinks:your-domain.com`
3. Host the `apple-app-site-association` file on your server

## Configuration Options

```dart
await LinkGravityClient.initialize(
  baseUrl: 'https://api.linkgravity.io',
  apiKey: 'your-api-key',
  config: LinkGravityConfig(
    logLevel: LogLevel.info,
    enableDeepLinking: true,
    enableAnalytics: true,
    enableOfflineQueue: true,
    batchSize: 10,
    batchTimeout: Duration(seconds: 30),
    requestTimeout: Duration(seconds: 30),
  ),
);
```

## API Reference

### LinkGravityClient

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize the SDK |
| `createLink()` | Create a new LinkGravity link |
| `getLink()` | Get link by ID |
| `updateLink()` | Update an existing link |
| `deleteLink()` | Delete a link |
| `trackEvent()` | Track a custom event |
| `trackConversion()` | Track a conversion event |
| `handleDeferredDeepLink()` | Manually handle deferred deep links |
| `onDeepLink` | Stream of incoming deep links |
| `flushEvents()` | Flush pending analytics events |

### DeferredLinkResponse

| Property | Description |
|----------|-------------|
| `success` | Whether a match was found |
| `deepLinkUrl` | The deep link URL |
| `matchMethod` | How the match was made: `referrer` or `fingerprint` |
| `linkId` | The associated link ID |
| `isDeterministic` | True if matched via Android referrer |
| `isProbabilistic` | True if matched via fingerprint |

## FlutterFlow Integration

See documentation for FlutterFlow Custom Actions.

## Troubleshooting

### Android Install Referrer Not Working

1. Ensure Google Play Services is available on the device
2. The app must be installed from the Play Store (not sideloaded)
3. Check that the LinkGravity link includes the `deferred_link` parameter

### Deep Links Not Working

1. Verify your Universal Links (iOS) or App Links (Android) setup
2. Check that your domain's `.well-known/assetlinks.json` or `apple-app-site-association` is correctly configured
3. Test with `adb shell am start` (Android) or Safari (iOS)

### Fingerprint Matching Inaccurate

Fingerprint matching is probabilistic and can be affected by:
- VPN usage
- Multiple users on the same network
- Different browsers/apps for click and install

Consider using Android Play Install Referrer for critical attribution needs.

## License

MIT License

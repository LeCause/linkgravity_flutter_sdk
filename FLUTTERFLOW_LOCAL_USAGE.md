# Using LinkGravity SDK Locally in FlutterFlow

There are **3 ways** to use the LinkGravity SDK in FlutterFlow without publishing to pub.dev:

---

## ✅ Option A: Git Repository (RECOMMENDED)

This is the most flexible and FlutterFlow-compatible approach.

### Step 1: Create Git Repository

1. **Initialize git** in SDK folder:
   ```bash
   cd linkgravity_flutter_sdk
   git init
   git add .
   git commit -m "Initial LinkGravity SDK"
   ```

2. **Push to private repository** (GitHub, GitLab, Bitbucket):
   ```bash
   # GitHub example
   git remote add origin https://github.com/your-org/linkgravity_flutter_sdk.git
   git branch -M main
   git push -u origin main
   ```

### Step 2: Use in FlutterFlow

1. **Open FlutterFlow** → Settings → Dependencies

2. **Add git dependency** in `pubspec.yaml`:
   ```yaml
   dependencies:
     linkgravity_flutter_sdk:
       git:
         url: https://github.com/your-org/linkgravity_flutter_sdk.git
         ref: main  # or specific commit/tag
   ```

3. **Save** and FlutterFlow will fetch from Git

### Advantages:
- ✅ Works in FlutterFlow UI
- ✅ No code download needed
- ✅ Can use private repositories
- ✅ Version control with tags/branches
- ✅ Team can access same version

### Authentication (Private Repos):

**GitHub Personal Access Token**:
```yaml
dependencies:
  linkgravity_flutter_sdk:
    git:
      url: https://your-token@github.com/your-org/linkgravity_flutter_sdk.git
      ref: main
```

---

## Option B: Local Path (Development Only)

Use when developing SDK locally, testing changes frequently.

### Requirements:
- Must **download FlutterFlow code**
- Cannot use FlutterFlow's Test Mode
- Path must be accessible

### Step 1: Download FlutterFlow Project

1. **FlutterFlow** → Project Menu → **Download Code**
2. Extract to local folder

### Step 2: Add Path Dependency

1. **Edit `pubspec.yaml`** manually:
   ```yaml
   dependencies:
     linkgravity_flutter_sdk:
       path: C:/linkgravity/linkgravity/linkgravity_flutter_sdk  # Windows
       # path: /Users/you/linkgravity/linkgravity_flutter_sdk  # Mac
       # path: /home/you/linkgravity/linkgravity_flutter_sdk   # Linux
   ```

2. **Run**:
   ```bash
   flutter pub get
   flutter run
   ```

### Advantages:
- ✅ Instant SDK updates during development
- ✅ No git commits needed for testing

### Disadvantages:
- ❌ Must download code each time FlutterFlow updates
- ❌ Path must exist on every developer's machine
- ❌ Won't work in FlutterFlow Test Mode
- ❌ Manual sync required

---

## Option C: Local Network Server (Advanced)

Host SDK on local network, FlutterFlow fetches via HTTP.

### Step 1: Create Pub Server

1. **Install pub_server**:
   ```bash
   dart pub global activate pub_server
   ```

2. **Run server**:
   ```bash
   cd linkgravity
   dart pub global run pub_server -p 8080 --directory .
   ```

3. **Server runs** on: `http://localhost:8080`

### Step 2: Use in FlutterFlow

```yaml
dependencies:
  linkgravity_flutter_sdk:
    hosted:
      name: linkgravity_flutter_sdk
      url: http://YOUR_LOCAL_IP:8080
    version: ^1.0.0
```

### Advantages:
- ✅ Multiple projects can use same server
- ✅ Version management

### Disadvantages:
- ❌ Complex setup
- ❌ Server must be running
- ❌ Network dependency

---

## 🚀 Deferred Deep Linking (LINK-004)

The SDK now supports **deterministic deferred deep linking** on Android using the Play Install Referrer API!

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                     SDK INITIALIZATION                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Is First Launch?                              │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │ YES                           │ NO
              ▼                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Check Platform                                  │
└─────────────────────────────────────────────────────────────────┘
              │
    ┌─────────┴─────────┐
    │ ANDROID           │ iOS
    ▼                   ▼
┌─────────────────────┐ ┌─────────────────────────────────────────┐
│ Play Install        │ │ Fingerprint Matching                     │
│ Referrer API        │ │ (~85-90% accuracy)                       │
│ (100% accurate)     │ │                                          │
└─────────────────────┘ └─────────────────────────────────────────┘
              │                   │
              ▼                   │
┌─────────────────────┐           │
│ Token found?        │           │
│ YES → Use referrer  │           │
│ NO → Fallback to    │───────────┘
│      fingerprint    │
└─────────────────────┘
```

### Platform-Specific Behavior

| Platform | Primary Method | Accuracy | Fallback |
|----------|---------------|----------|----------|
| **Android** | Play Install Referrer | 100% | Fingerprint |
| **iOS** | Fingerprint | ~85-90% | - |

### Custom Action: Check Deferred Deep Link

```dart
import 'dart:io';
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

/// Check for deferred deep link and get match details
/// Returns JSON with deepLinkUrl and matchMethod
Future<String?> checkDeferredDeepLink() async {
  try {
    String? result;

    await LinkGravityClient.instance.handleDeferredDeepLink(
      onFound: () {
        print('Deferred deep link found!');
      },
      onNotFound: () {
        print('No deferred deep link');
      },
    ).then((deepLinkUrl) {
      if (deepLinkUrl != null) {
        // Return info about the match
        final matchMethod = Platform.isAndroid ? 'referrer' : 'fingerprint';
        result = '{"deepLinkUrl": "$deepLinkUrl", "matchMethod": "$matchMethod"}';
      }
    });

    return result;
  } catch (e) {
    print('Error checking deferred deep link: $e');
    return null;
  }
}
```

### Custom Action: Get Attribution Source

```dart
import 'dart:io';

/// Get the attribution source type for the current platform
/// Returns: "deterministic" (Android) or "probabilistic" (iOS)
String getAttributionSourceType() {
  if (Platform.isAndroid) {
    return 'deterministic'; // Play Install Referrer - 100% accurate
  } else if (Platform.isIOS) {
    return 'probabilistic'; // Fingerprint matching - ~85-90% accurate
  }
  return 'unknown';
}
```

### Display Attribution Method in UI

In FlutterFlow, you can show users how they were attributed:

```dart
import 'dart:io';
import 'package:flutter/material.dart';

/// Widget to display attribution method
Widget buildAttributionInfo() {
  final isAndroid = Platform.isAndroid;

  return Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isAndroid ? Colors.green.shade50 : Colors.orange.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(
          isAndroid ? Icons.verified : Icons.fingerprint,
          color: isAndroid ? Colors.green : Colors.orange,
        ),
        SizedBox(width: 8),
        Text(
          isAndroid
            ? 'Attribution: Play Install Referrer (100% accurate)'
            : 'Attribution: Fingerprint Matching (~85-90% accurate)',
          style: TextStyle(
            color: isAndroid ? Colors.green.shade700 : Colors.orange.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
```

---

## 🎯 Recommended Workflow

### For Your Use Case (Local Network Testing):

**Phase 1: Development** (Use Option B - Path)
1. Download FlutterFlow project
2. Add SDK as path dependency
3. Develop and test locally
4. Make SDK changes → instantly reflected

**Phase 2: Team Testing** (Use Option A - Git)
1. Commit SDK to private Git repo
2. Update FlutterFlow to use Git dependency
3. Team can test without path issues
4. Can upload directly in FlutterFlow UI

**Phase 3: Production** (Publish to pub.dev)
1. Publish SDK to pub.dev
2. Update to: `linkgravity_flutter_sdk: ^1.0.0`
3. Public availability

---

## 📝 Example: Complete Setup (Git Method)

### 1. Prepare SDK

```bash
cd linkgravity_flutter_sdk

# Initialize git
git init
git add .
git commit -m "feat: LinkGravity SDK v1.0.0"

# Create GitHub repo (via UI or CLI)
gh repo create linkgravity_flutter_sdk --private

# Push
git remote add origin https://github.com/your-org/linkgravity_flutter_sdk.git
git push -u origin main

# Tag version
git tag v1.0.0
git push --tags
```

### 2. FlutterFlow Configuration

In **Settings → Dependencies → pubspec.yaml**:

```yaml
name: your_app
description: Your FlutterFlow App

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # LinkGravity SDK from private Git
  linkgravity_flutter_sdk:
    git:
      url: https://github.com/your-org/linkgravity_flutter_sdk.git
      ref: v1.0.0  # Use specific version tag
```

### 3. Create Custom Actions

**Action: initializeLinkGravity**
```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

Future<bool> initializeLinkGravity(String baseUrl) async {
  try {
    await LinkGravityClient.initialize(
      baseUrl: baseUrl,
      apiKey: 'demo-api-key',
      config: LinkGravityConfig(
        enableAnalytics: true,
        enableDeepLinking: true,
        logLevel: LogLevel.debug,
      ),
    );
    return true;
  } catch (e) {
    print('LinkGravity init failed: $e');
    return false;
  }
}
```

**Action: setupDeepLinkListener**
```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

Future<void> setupDeepLinkListener(BuildContext context) async {
  LinkGravityClient.instance.onDeepLink.listen((deepLink) {
    print('Deep link: ${deepLink.path}');

    // Navigate based on path
    if (deepLink.path.startsWith('/hidden')) {
      context.pushNamed('HiddenPage');
    }
  });
}
```

**Action: trackConversion** (NEW)
```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

/// Track a conversion event (purchase, signup, etc.)
Future<bool> trackLinkGravityConversion({
  required String type,
  double? revenue,
  String currency = 'USD',
  String? linkId,
}) async {
  try {
    return await LinkGravityClient.instance.trackConversion(
      type: type,
      revenue: revenue,
      currency: currency,
      linkId: linkId,
    );
  } catch (e) {
    print('Failed to track conversion: $e');
    return false;
  }
}
```

### 4. App Initialization

**App Settings → On App Start:**
1. Add Custom Action: `initializeLinkGravity`
   - Pass parameter: `baseUrl` = `http://YOUR_LOCAL_IP:3000`
2. Add Custom Action: `setupDeepLinkListener`

---

## 🔄 Updating SDK

### Git Method

```bash
# Make changes to SDK
cd linkgravity_flutter_sdk
# ... edit files ...

# Commit and tag new version
git add .
git commit -m "feat: Add new feature"
git tag v1.0.1
git push origin main --tags

# Update in FlutterFlow pubspec.yaml:
# Change ref: v1.0.0 → ref: v1.0.1
```

### Path Method

```bash
# Make changes to SDK
# ... edit files ...

# In your FlutterFlow project:
flutter pub get  # Fetches latest from path
flutter run      # Test changes
```

---

## 🐛 Troubleshooting

### Issue: "Could not resolve package"

**Git Method**:
- Verify repo URL is correct
- Check authentication (private repos need token)
- Ensure ref/tag exists

**Path Method**:
- Verify path exists and is correct
- Use absolute paths
- Check forward slashes (even on Windows)

### Issue: "SDK not found in FlutterFlow"

**Solution**:
- Git dependency requires code download
- FlutterFlow Test Mode doesn't support custom packages
- Download code and run locally: `flutter run`

### Issue: "Version solving failed"

**Solution**:
- Check Flutter/Dart SDK version compatibility
- SDK requires: `sdk: ^3.10.0`, `flutter: >=3.38.0`
- Update Flutter: `flutter upgrade`

### Issue: "Play Install Referrer not working"

**Android-specific troubleshooting**:
1. App must be installed from Play Store (not sideloaded/debug)
2. Google Play Services must be available on device
3. LinkGravity backend must include `deferred_link` parameter in Play Store URL
4. Check logs for: `Retrieving Play Install Referrer...`

**Expected log output (success)**:
```
I/LinkGravity: Retrieving Play Install Referrer...
I/LinkGravity: Found deferred_link token: eyJsaWQiOiJjbWk3NW...
I/LinkGravity: ✅ Deterministic match found via referrer!
```

**Expected log output (fallback to fingerprint)**:
```
I/LinkGravity: Retrieving Play Install Referrer...
D/LinkGravity: Empty referrer URL
D/LinkGravity: Referrer lookup failed, falling back to fingerprint...
I/LinkGravity: Using fingerprint matching...
```

---

## ✅ Quick Checklist

Before using SDK in FlutterFlow:

- [ ] SDK tests pass: `flutter test`
- [ ] Git repo created (if using Git method)
- [ ] Dependency added to pubspec.yaml
- [ ] Custom Actions created (init + listener)
- [ ] App initialization configured
- [ ] Code downloaded (if using path/local testing)
- [ ] Platform files updated (Info.plist, AndroidManifest.xml)
- [ ] (Android) Play Install Referrer tested on real device from Play Store

---

## 🎯 Summary

| Method | Best For | FlutterFlow UI | Team Use | Effort |
|--------|----------|----------------|----------|--------|
| **Git** | Team testing, staging | ✅ Yes | ✅ Yes | Medium |
| **Path** | Solo development | ❌ No | ❌ No | Low |
| **Server** | Enterprise, CI/CD | ✅ Yes | ✅ Yes | High |

**Recommendation**: Use **Git** for your scenario (team testing on local network).

---

## 📊 Deferred Deep Linking Comparison

| Feature | Android (Play Install Referrer) | iOS (Fingerprint) |
|---------|--------------------------------|-------------------|
| Accuracy | 100% deterministic | ~85-90% probabilistic |
| Requirements | Play Store install | None |
| Fallback | Fingerprint matching | - |
| Privacy | No PII needed | Device attributes |
| Setup | Automatic (SDK handles) | Automatic |

---

For detailed testing instructions, see [FLUTTERFLOW_LOCAL_TESTING.md](FLUTTERFLOW_LOCAL_TESTING.md)

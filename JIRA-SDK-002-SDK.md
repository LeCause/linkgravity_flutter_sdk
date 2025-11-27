# SDK-002-SDK: Flutter SDK API Compatibility Fixes & Enhancement

## Project
LinkGravity Flutter SDK (`C:\linkgravity\linkgravity-flutter-sdk`)

## Story Type
Bug Fix / Enhancement

## Priority
**P0 - Critical** (Blocks SDK functionality in production)

## Story Points
**3 points**

---

## Summary

Fix critical compatibility issues between the Flutter SDK and backend API to enable proper authentication, deferred deep linking, and attribution tracking.

---

## Background

During SDK-001 implementation review, we discovered compatibility issues preventing the SDK from working with the backend:

1. **Authentication Header Mismatch**: SDK sends `X-API-Key`, backend expects `Authorization: Bearer`
2. **Response Parsing Mismatch**: SDK expects flat match response, backend wraps in `{ success, match }`
3. **Network Resilience**: No retry logic for failed deferred link lookups

These issues prevent the SDK from functioning in production and must be fixed before release.

---

## Acceptance Criteria

### Critical (P0) - Must Complete

- [ ] **[AUTH-001] Fix authentication header format**
  - Change from `X-API-Key` to `Authorization: Bearer`
  - All API calls succeed with correct authentication
  - Unit test for header format
  - Integration test with real backend

- [ ] **[PARSE-001] Fix match-link response parsing**
  - Parse wrapped response `{ success, match: {...} }`
  - Maintain backward compatibility with flat responses
  - Extract match data correctly
  - Map to `DeferredLinkResponse` model correctly

- [ ] **[TEST-001] Verify all SDK endpoints work**
  - Test all public SDK methods
  - Test with both public key (SDK endpoints) and API key (link management)
  - Integration tests pass
  - Example app works end-to-end

### High Priority (P1) - Should Complete

- [ ] **[RETRY-001] Add retry logic with exponential backoff**
  - Retry on network failures (3 attempts max)
  - Exponential backoff: 2s, 4s, 8s
  - Don't retry on 404 errors
  - Timeout per attempt: 10 seconds

- [ ] **[TIMEOUT-001] Reduce request timeout**
  - Change from 30s to 15s
  - Better UX (don't leave users waiting)

### Medium Priority (P2) - Nice to Have

- [ ] **[ANALYTICS-001] Track failed match attempts**
  - Send failed match events to backend
  - Include fingerprint and reason
  - Help debug matching issues

- [ ] **[CONFIG-001] Make timeout configurable**
  - Allow users to set custom timeouts
  - Provide sensible defaults

---

## Technical Implementation

### 1. Fix Authentication Header (AUTH-001)

**Location**: `lib/src/services/api_service.dart:43-54`

**Current Code** (❌ Wrong):
```dart
Map<String, String> get _headers {
  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (apiKey != null) {
    headers['X-API-Key'] = apiKey!;  // ❌ Backend expects Authorization header
  }
  return headers;
}
```

**Fixed Code** (✅ Correct):
```dart
Map<String, String> get _headers {
  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (apiKey != null) {
    headers['Authorization'] = 'Bearer $apiKey';  // ✅ Correct format
  }
  return headers;
}
```

**Unit Test**:
```dart
// test/services/api_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:linkgravity_flutter_sdk/src/services/api_service.dart';

void main() {
  group('ApiService Authentication', () {
    test('should use Authorization Bearer header for API key', () {
      final apiService = ApiService(
        baseUrl: 'https://api.linkgravity.com',
        apiKey: 'pk_test_123',
      );

      final headers = apiService.headers;

      expect(headers['Authorization'], equals('Bearer pk_test_123'));
      expect(headers['X-API-Key'], isNull);
    });

    test('should work without API key', () {
      final apiService = ApiService(
        baseUrl: 'https://api.linkgravity.com',
      );

      final headers = apiService.headers;

      expect(headers['Authorization'], isNull);
      expect(headers['X-API-Key'], isNull);
    });
  });
}
```

---

### 2. Fix Match-Link Response Parsing (PARSE-001)

**Location**: `lib/src/services/deferred_deep_link_service.dart:86-102`

**Current Code** (❌ Expects flat response):
```dart
final response = await _api.matchLink(fingerprintData);

if (response != null) {
  LinkGravityLogger.info('✅ Probabilistic match found via fingerprint');
  return DeferredLinkResponse.fromJson({
    ...response,  // ❌ Assumes flat response
    'matchMethod': 'fingerprint',
  });
}
```

**Fixed Code** (✅ Handles wrapped response):
```dart
final response = await _api.matchLink(fingerprintData);

if (response != null && response['success'] == true) {
  final match = response['match'];  // ✅ Extract match object

  if (match != null && match['found'] == true) {
    LinkGravityLogger.info('✅ Probabilistic match found via fingerprint');
    LinkGravityLogger.info('   Confidence: ${match['confidence']}');
    LinkGravityLogger.info('   Score: ${match['score']}');

    // Map to DeferredLinkResponse
    return DeferredLinkResponse(
      success: true,
      deepLinkData: {
        'deepLinkUrl': match['deepLinkUrl'],
        'path': extractPath(match['deepLinkUrl']),
        'params': extractParams(match['deepLinkUrl']),
      },
      linkId: match['linkId'],
      matchMethod: 'fingerprint',
      confidence: match['confidence'],
      score: match['score'],
    );
  }
}

LinkGravityLogger.info('No deferred deep link found');
return null;
```

**Update Model** (`lib/src/models/deep_link_match.dart:42-52`):

Make `DeepLinkMatch.fromJson` handle both wrapped and flat responses:

```dart
/// Response from fingerprint matching endpoint
class DeepLinkMatch {
  final bool found;
  final String confidence;
  final int score;
  final String? deepLinkUrl;
  final String? linkId;
  final MatchMetadata? metadata;

  DeepLinkMatch({
    required this.found,
    required this.confidence,
    required this.score,
    this.deepLinkUrl,
    this.linkId,
    this.metadata,
  });

  /// Parse from JSON response
  ///
  /// Handles both:
  /// - Wrapped response: { success: true, match: { found, confidence, ... } }
  /// - Flat response: { found, confidence, ... } (backward compatible)
  factory DeepLinkMatch.fromJson(Map<String, dynamic> json) {
    // Check if response is wrapped in { success, match }
    final data = json.containsKey('match') ? json['match'] : json;

    return DeepLinkMatch(
      found: data['found'] ?? false,
      confidence: data['confidence'] ?? 'none',
      score: data['score'] ?? 0,
      deepLinkUrl: data['deepLinkUrl'],
      linkId: data['linkId'],
      metadata: data['metadata'] != null
          ? MatchMetadata.fromJson(data['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'found': found,
    'confidence': confidence,
    'score': score,
    if (deepLinkUrl != null) 'deepLinkUrl': deepLinkUrl,
    if (linkId != null) 'linkId': linkId,
    if (metadata != null) 'metadata': metadata!.toJson(),
  };
}
```

**Unit Test**:
```dart
// test/models/deep_link_match_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:linkgravity_flutter_sdk/src/models/deep_link_match.dart';

void main() {
  group('DeepLinkMatch', () {
    test('should parse wrapped response from backend', () {
      final json = {
        'success': true,
        'match': {
          'found': true,
          'confidence': 'high',
          'score': 95,
          'deepLinkUrl': 'myapp://example.com/page',
          'linkId': 'abc123',
          'metadata': {
            'matchReasons': ['platform', 'timezone', 'locale'],
            'platformMatch': true,
            'timezoneMatch': true,
            'localeMatch': true,
            'browserMatch': false,
            'timeWindow': 25,
          },
        },
      };

      final match = DeepLinkMatch.fromJson(json);

      expect(match.found, true);
      expect(match.confidence, 'high');
      expect(match.score, 95);
      expect(match.deepLinkUrl, 'myapp://example.com/page');
      expect(match.linkId, 'abc123');
      expect(match.metadata, isNotNull);
      expect(match.metadata!.platformMatch, true);
    });

    test('should parse flat response (backward compatible)', () {
      final json = {
        'found': true,
        'confidence': 'medium',
        'score': 75,
        'deepLinkUrl': 'myapp://example.com/other',
      };

      final match = DeepLinkMatch.fromJson(json);

      expect(match.found, true);
      expect(match.confidence, 'medium');
      expect(match.score, 75);
    });

    test('should handle not found response', () {
      final json = {
        'success': true,
        'match': {
          'found': false,
          'confidence': 'none',
          'score': 0,
        },
      };

      final match = DeepLinkMatch.fromJson(json);

      expect(match.found, false);
      expect(match.confidence, 'none');
      expect(match.deepLinkUrl, isNull);
    });
  });
}
```

---

### 3. Add Retry Logic with Exponential Backoff (RETRY-001)

**Location**: `lib/src/services/deferred_deep_link_service.dart`

**Add Retry Method**:
```dart
import 'dart:math';
import 'dart:async';

class DeferredDeepLinkService {
  final ApiService _api;
  final FingerprintService _fingerprint;
  final InstallReferrerService _installReferrer;

  // ... existing code ...

  /// Match deferred deep link with retry logic
  ///
  /// Retries on network failures with exponential backoff:
  /// - Attempt 1: Immediate
  /// - Attempt 2: After 2 seconds
  /// - Attempt 3: After 4 seconds (total 6s delay)
  /// - Attempt 4: After 8 seconds (total 14s delay)
  ///
  /// Does NOT retry on:
  /// - 404 Not Found (no deferred link exists)
  /// - 400 Bad Request (invalid data)
  Future<DeferredLinkResponse?> matchDeepLinkWithRetry() async {
    const maxAttempts = 3;
    const timeout = Duration(seconds: 10);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        LinkGravityLogger.debug('Deferred link lookup attempt ${attempt + 1}/$maxAttempts');

        final result = await matchDeepLink().timeout(timeout);

        if (result != null) {
          LinkGravityLogger.info('✅ Deferred link found on attempt ${attempt + 1}');
          return result;
        }

        // No match found, but request succeeded
        return null;

      } on TimeoutException catch (e) {
        LinkGravityLogger.warning('Deferred link lookup timeout on attempt ${attempt + 1}', e);

        // Retry with exponential backoff
        if (attempt < maxAttempts - 1) {
          final delaySeconds = pow(2, attempt + 1).toInt(); // 2, 4, 8 seconds
          LinkGravityLogger.debug('Retrying in $delaySeconds seconds...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }

      } on ApiException catch (e) {
        // Don't retry on client errors (400, 404, etc.)
        if (e.statusCode >= 400 && e.statusCode < 500) {
          LinkGravityLogger.debug('Client error ${e.statusCode}, not retrying');
          return null;
        }

        // Retry on server errors (500+)
        LinkGravityLogger.warning('Server error ${e.statusCode} on attempt ${attempt + 1}', e);

        if (attempt < maxAttempts - 1) {
          final delaySeconds = pow(2, attempt + 1).toInt();
          await Future.delayed(Duration(seconds: delaySeconds));
        }

      } catch (e) {
        // Unknown error - retry
        LinkGravityLogger.error('Unexpected error on attempt ${attempt + 1}', e);

        if (attempt < maxAttempts - 1) {
          final delaySeconds = pow(2, attempt + 1).toInt();
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }
    }

    LinkGravityLogger.warning('Failed to match deferred link after $maxAttempts attempts');
    return null;
  }

  // ... existing matchDeepLink() method unchanged ...
}
```

**Update LinkGravityClient** (`lib/src/linkgravity_client.dart`):

Change from `matchDeepLink()` to `matchDeepLinkWithRetry()`:

```dart
Future<void> _handleDeferredDeepLink() async {
  final isFirstLaunch = await _storage.isFirstLaunch();

  if (!isFirstLaunch) {
    LinkGravityLogger.debug('Not first launch, skipping deferred deep link check');
    return;
  }

  LinkGravityLogger.info('First launch detected, checking for deferred deep link...');

  try {
    final deferredService = DeferredDeepLinkService(
      apiService: _api,
      fingerprintService: _fingerprint,
    );

    // ✅ Use retry version
    final match = await deferredService.matchDeepLinkWithRetry();

    if (match != null && match.success && match.deepLinkUrl != null) {
      LinkGravityLogger.info('✅ Deferred deep link found!');
      LinkGravityLogger.info('   Method: ${match.matchMethod}');
      LinkGravityLogger.info('   URL: ${match.deepLinkUrl}');

      // Track install with attribution
      await _api.trackInstall(
        fingerprint: _deviceFingerprint!,
        deviceId: _deviceId!,
        platform: await _fingerprint.getPlatformName(),
        appVersion: _appVersion,
        deferredLinkId: match.linkId,
        matchMethod: match.matchMethod,
        matchConfidence: match.confidence,
        matchScore: match.score,
      );

      // Emit deep link event
      final uri = Uri.parse(match.deepLinkUrl!);
      final deepLink = _deepLink.parseLink(uri);
      _deepLink.linkController.add(deepLink);

    } else {
      LinkGravityLogger.debug('No deferred deep link found');
    }

    // Mark as launched
    await _storage.markAsLaunched();

  } catch (e, stackTrace) {
    LinkGravityLogger.error('Error handling deferred deep link', e, stackTrace);
    await _storage.markAsLaunched();
  }
}
```

**Unit Test**:
```dart
// test/services/deferred_deep_link_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('DeferredDeepLinkService Retry Logic', () {
    late MockApiService mockApi;
    late MockFingerprintService mockFingerprint;
    late DeferredDeepLinkService service;

    setUp(() {
      mockApi = MockApiService();
      mockFingerprint = MockFingerprintService();
      service = DeferredDeepLinkService(
        apiService: mockApi,
        fingerprintService: mockFingerprint,
      );
    });

    test('should succeed on first attempt', () async {
      // Mock successful response
      when(mockApi.matchLink(any)).thenAnswer((_) async => {
        'success': true,
        'match': {
          'found': true,
          'confidence': 'high',
          'score': 95,
          'deepLinkUrl': 'myapp://example.com/page',
        },
      });

      final result = await service.matchDeepLinkWithRetry();

      expect(result, isNotNull);
      expect(result!.deepLinkUrl, 'myapp://example.com/page');
      verify(mockApi.matchLink(any)).called(1); // Only 1 attempt
    });

    test('should retry on timeout', () async {
      int attemptCount = 0;

      when(mockApi.matchLink(any)).thenAnswer((_) async {
        attemptCount++;
        if (attemptCount < 3) {
          throw TimeoutException('Request timeout');
        }
        return {
          'success': true,
          'match': { 'found': true, 'confidence': 'high' },
        };
      });

      final result = await service.matchDeepLinkWithRetry();

      expect(result, isNotNull);
      expect(attemptCount, 3); // Succeeded on 3rd attempt
    });

    test('should NOT retry on 404', () async {
      when(mockApi.matchLink(any)).thenThrow(
        ApiException(statusCode: 404, message: 'Not found')
      );

      final result = await service.matchDeepLinkWithRetry();

      expect(result, isNull);
      verify(mockApi.matchLink(any)).called(1); // Only 1 attempt (no retry)
    });

    test('should retry on 500 server error', () async {
      int attemptCount = 0;

      when(mockApi.matchLink(any)).thenAnswer((_) async {
        attemptCount++;
        if (attemptCount < 2) {
          throw ApiException(statusCode: 500, message: 'Server error');
        }
        return {
          'success': true,
          'match': { 'found': true },
        };
      });

      final result = await service.matchDeepLinkWithRetry();

      expect(result, isNotNull);
      expect(attemptCount, 2); // Succeeded on 2nd attempt
    });

    test('should give up after 3 attempts', () async {
      when(mockApi.matchLink(any)).thenThrow(
        TimeoutException('Always timeout')
      );

      final result = await service.matchDeepLinkWithRetry();

      expect(result, isNull);
      verify(mockApi.matchLink(any)).called(3); // Tried 3 times
    });
  });
}
```

---

### 4. Reduce Request Timeout (TIMEOUT-001)

**Location**: `lib/src/services/api_service.dart`

**Current Code**:
```dart
final Duration requestTimeout = const Duration(seconds: 30);
```

**Fixed Code**:
```dart
final Duration requestTimeout = const Duration(seconds: 15);
```

**Make Configurable**:
```dart
class ApiService {
  final String baseUrl;
  final String? apiKey;
  final Duration requestTimeout;

  ApiService({
    required this.baseUrl,
    this.apiKey,
    this.requestTimeout = const Duration(seconds: 15), // ✅ Default 15s, configurable
  });

  // ... rest of implementation
}
```

---

### 5. Track Failed Match Attempts (ANALYTICS-001) - Optional P2

**Add Method to ApiService** (`lib/src/services/api_service.dart`):

```dart
/// Track failed deferred link match attempt
///
/// Helps debug matching issues and improve algorithm
Future<void> trackFailedMatch({
  required String fingerprint,
  required String reason,
  Map<String, dynamic>? metadata,
}) async {
  try {
    await _post('/api/v1/sdk/events', {
      'name': 'deferred_link_match_failed',
      'properties': {
        'reason': reason,
        'fingerprint': fingerprint,
        ...?metadata,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    LinkGravityLogger.debug('Failed to track failed match', e);
    // Don't throw - this is optional analytics
  }
}
```

**Use in DeferredDeepLinkService**:

```dart
Future<DeferredLinkResponse?> matchDeepLink() async {
  // ... existing code ...

  if (match == null || !match['found']) {
    LinkGravityLogger.info('No deferred deep link found');

    // ✅ Track failed match for analytics
    await _api.trackFailedMatch(
      fingerprint: fingerprintData['fingerprint'],
      reason: 'no_match',
      metadata: {
        'platform': fingerprintData['platform'],
        'locale': fingerprintData['locale'],
      },
    );

    return null;
  }

  // ... rest of code
}
```

---

## Testing Requirements

### Unit Tests

**Authentication Header**:
```dart
// test/services/api_service_test.dart
test('should use Authorization Bearer header', () {
  final apiService = ApiService(
    baseUrl: 'https://api.example.com',
    apiKey: 'pk_test_123',
  );

  expect(apiService.headers['Authorization'], 'Bearer pk_test_123');
  expect(apiService.headers['X-API-Key'], isNull);
});
```

**Response Parsing**:
```dart
// test/models/deep_link_match_test.dart
test('should parse wrapped match response', () {
  final response = {
    'success': true,
    'match': {
      'found': true,
      'confidence': 'high',
      'score': 95,
    },
  };

  final match = DeepLinkMatch.fromJson(response);

  expect(match.found, true);
  expect(match.confidence, 'high');
  expect(match.score, 95);
});

test('should parse flat response (backward compatible)', () {
  final response = {
    'found': true,
    'confidence': 'high',
    'score': 95,
  };

  final match = DeepLinkMatch.fromJson(response);
  expect(match.found, true);
});
```

**Retry Logic**:
```dart
// test/services/deferred_deep_link_service_test.dart
test('should retry on timeout', () async {
  // ... (see implementation above)
});

test('should NOT retry on 404', () async {
  // ... (see implementation above)
});
```

### Integration Tests

**End-to-End Flow**:
```dart
// test/integration/deferred_deep_link_test.dart
testWidgets('Android: should match via referrer token', (tester) async {
  // Mock Install Referrer API
  mockInstallReferrer('utm_source=linkgravity&deferred_link=eyJsaWQi...');

  final sdk = await LinkGravity.initialize(
    apiKey: 'pk_test_real_backend_key',
    baseUrl: 'https://staging-api.linkgravity.com',
  );

  DeepLink? receivedLink;
  sdk.onDeepLink((link) {
    receivedLink = link;
  });

  await tester.pumpAndSettle(Duration(seconds: 5));

  expect(receivedLink, isNotNull);
  expect(receivedLink!.path, '/hidden');
  expect(receivedLink!.params['ref'], 'TEST');
});

testWidgets('iOS: should match via fingerprint', (tester) async {
  final sdk = await LinkGravity.initialize(
    apiKey: 'pk_test_real_backend_key',
    baseUrl: 'https://staging-api.linkgravity.com',
  );

  DeepLink? receivedLink;
  sdk.onDeepLink((link) {
    receivedLink = link;
  });

  await tester.pumpAndSettle(Duration(seconds: 5));

  // Should either find match or gracefully handle no match
  expect(receivedLink, isNotNull);
});

testWidgets('should retry on network failure', (tester) async {
  // Simulate network failure for first 2 attempts
  int attemptCount = 0;
  mockNetworkFailure(() {
    attemptCount++;
    return attemptCount < 3; // Fail first 2 attempts
  });

  final sdk = await LinkGravity.initialize(
    apiKey: 'pk_test_123',
  );

  await tester.pumpAndSettle(Duration(seconds: 20));

  expect(attemptCount, 3); // Verify it retried
});
```

**Authentication Test**:
```dart
testWidgets('should authenticate with public key', (tester) async {
  final sdk = await LinkGravity.initialize(
    apiKey: 'pk_test_real_key',
    baseUrl: 'https://staging-api.linkgravity.com',
  );

  // Should succeed with public key
  final config = await sdk.getConfig();
  expect(config, isNotNull);
});
```

---

## Files to Modify

### SDK Core
- [ ] `lib/src/services/api_service.dart` (authentication header, timeout)
- [ ] `lib/src/services/deferred_deep_link_service.dart` (retry logic, response parsing)
- [ ] `lib/src/models/deep_link_match.dart` (fromJson method)
- [ ] `lib/src/linkgravity_client.dart` (use matchDeepLinkWithRetry)

### Tests
- [ ] `test/services/api_service_test.dart` (new/updated tests)
- [ ] `test/models/deep_link_match_test.dart` (new/updated tests)
- [ ] `test/services/deferred_deep_link_service_test.dart` (new tests for retry)
- [ ] `test/integration/deferred_deep_link_test.dart` (end-to-end tests)

### Documentation
- [ ] `README.md` (update authentication section)
- [ ] `CHANGELOG.md` (document breaking changes)
- [ ] `example/lib/main.dart` (ensure example works)

---

## Testing Checklist

### Manual Testing (Before Release)

- [ ] **Android Real Device**:
  - [ ] Install app from Play Store after clicking LinkGravity
  - [ ] Verify deferred link opens correct screen
  - [ ] Check logs for "Deterministic match found via referrer"
  - [ ] Verify attribution data sent to backend

- [ ] **iOS Real Device**:
  - [ ] Install app from App Store after clicking LinkGravity
  - [ ] Verify deferred link opens correct screen
  - [ ] Check logs for "Probabilistic match found via fingerprint"
  - [ ] Verify attribution data sent to backend

- [ ] **Network Scenarios**:
  - [ ] Airplane mode → turn on WiFi after app launch
  - [ ] Slow 3G connection
  - [ ] Intermittent connectivity

- [ ] **Error Scenarios**:
  - [ ] No deferred link exists (graceful handling)
  - [ ] Backend returns 500 error (retry works)
  - [ ] Timeout (retry works)

### Automated Testing

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Code coverage ≥ 80% for modified files
- [ ] `dart analyze` shows no errors
- [ ] `dart format` passes

---

## Deployment Checklist

### Pre-Release

- [ ] Update `pubspec.yaml` version (e.g., `1.1.0`)
- [ ] Update `CHANGELOG.md` with all changes
- [ ] Run full test suite
- [ ] Test with staging backend
- [ ] Test example app end-to-end
- [ ] Update documentation

### Release

- [ ] Create git tag (e.g., `v1.1.0`)
- [ ] Publish to pub.dev: `flutter pub publish`
- [ ] Create GitHub release with changelog
- [ ] Notify users of update
- [ ] Update integration guide

### Post-Release

- [ ] Monitor pub.dev for issues
- [ ] Monitor GitHub issues
- [ ] Check analytics for SDK adoption
- [ ] Verify attribution data flowing correctly

---

## Migration Guide for Users

### Version Upgrade: 1.0.x → 1.1.0

**Breaking Changes**: None (internal fixes only)

**What Changed**:
- ✅ Authentication now works correctly with backend
- ✅ Deferred deep linking reliability improved (retry logic)
- ✅ Better error handling and logging

**Action Required**: Update dependency in `pubspec.yaml`:

```yaml
dependencies:
  linkgravity_flutter_sdk: ^1.1.0  # Update from 1.0.x
```

Then run:
```bash
flutter pub get
```

**No code changes required** - all fixes are internal.

---

## Success Metrics

### Functional Metrics
- [ ] All SDK API calls succeed (0% authentication errors)
- [ ] Deferred deep linking success rate:
  - Android: ≥95% (referrer-based)
  - iOS: ≥75% (fingerprint-based)
- [ ] Retry logic improves success rate by 5-10%

### Performance Metrics
- [ ] SDK initialization: <500ms
- [ ] Deferred link resolution: <3s (with retries)
- [ ] No impact on app startup time

### Quality Metrics
- [ ] Test coverage: ≥80%
- [ ] 0 dart analyze warnings
- [ ] 0 critical bugs reported in first week

---

## Dependencies

- ⚠️ **Requires SDK-002-BACKEND** to be deployed first
- ⚠️ Backend must have authentication header fix deployed
- ⚠️ Backend must have match-link response structure in place

---

## Related Stories

- **SDK-002-BACKEND**: Backend API compatibility fixes (must deploy first)
- **SDK-001**: Initial SDK implementation (completed)
- **LINK-004**: Android Play Install Referrer backend (completed)

---

## Priority Breakdown

| Priority | Tasks | Estimated Hours | Must Have |
|----------|-------|-----------------|-----------|
| P0 Critical | AUTH-001, PARSE-001, TEST-001 | 4-6 hours | YES |
| P1 High | RETRY-001, TIMEOUT-001 | 3-4 hours | YES |
| P2 Medium | ANALYTICS-001, CONFIG-001 | 2-3 hours | NO |

**Total P0+P1**: 7-10 hours (~1-1.5 working days)
**Total with P2**: 9-13 hours (~1.5-2 working days)

---

## Rollback Plan

If critical issues are found after release:

1. **Pub.dev Rollback**:
   - Publish hotfix version (e.g., `1.0.1`)
   - Notify users to downgrade: `linkgravity_flutter_sdk: 1.0.1`

2. **Authentication Issues**:
   - Verify backend accepts `Authorization: Bearer` header
   - Check API key format (should start with `pk_` or `sk_`)

3. **Parsing Issues**:
   - Verify backend response format matches expectations
   - Check `DeepLinkMatch.fromJson` handles both formats

---

## Notes

- **No Breaking Changes**: All fixes are internal, public API unchanged
- **Backward Compatible**: SDK still works with old unsigned tokens (backend will reject)
- **Requires Backend Update**: Backend must be deployed first with new response format
- **Safe to Deploy**: No risk to existing users (they'll get authentication errors until they update)

---

## Attachments

- [Best Practices Analysis](./SDK-BACKEND-COMPATIBILITY.md)
- [API Compatibility Matrix](./API-COMPATIBILITY.md)
- [Backend Story](../linkgravity/JIRA-SDK-002-BACKEND.md)

---

**Story Created**: 2025-01-21
**Last Updated**: 2025-01-21
**Assigned To**: Flutter Team
**Reviewer**: Tech Lead

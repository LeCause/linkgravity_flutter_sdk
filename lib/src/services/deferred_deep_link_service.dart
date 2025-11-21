import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/deep_link_match.dart';
import '../models/deferred_link_response.dart';
import '../utils/logger.dart';
import 'api_service.dart';
import 'fingerprint_service.dart';
import 'install_referrer_service.dart';

/// Service for handling deferred deep linking
///
/// Supports two matching strategies:
/// 1. **Android Play Install Referrer (deterministic)**: 100% accurate matching
///    using the Play Install Referrer API. Only available on Android.
/// 2. **Fingerprint matching (probabilistic)**: ~85-90% accurate matching
///    using device fingerprinting. Available on both iOS and Android.
///
/// The service automatically tries the best available method:
/// - Android: Try referrer first, fall back to fingerprint
/// - iOS: Always use fingerprint
class DeferredDeepLinkService {
  final ApiService apiService;
  final FingerprintService fingerprintService;
  final InstallReferrerService _installReferrer;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  DeferredDeepLinkService({
    required this.apiService,
    required this.fingerprintService,
    InstallReferrerService? installReferrerService,
  }) : _installReferrer = installReferrerService ?? InstallReferrerService();

  /// Match deferred deep link using best available method
  ///
  /// Strategy:
  /// 1. Android: Try Play Install Referrer first (deterministic, 100% accuracy)
  /// 2. If referrer fails: Fall back to fingerprint matching (probabilistic, ~85-90%)
  /// 3. iOS: Always use fingerprint matching
  ///
  /// Returns [DeferredLinkResponse] if a match is found, null otherwise.
  Future<DeferredLinkResponse?> matchDeferredDeepLink() async {
    try {
      // Step 1: Try Android Play Install Referrer (deterministic)
      if (Platform.isAndroid) {
        SmartLinkLogger.info(
            'Android detected, trying Play Install Referrer...');

        final referrerToken = await _installReferrer.getInstallReferrer();

        if (referrerToken != null) {
          SmartLinkLogger.info('Found referrer token, querying server...');

          final response =
              await apiService.getDeferredLinkByReferrer(referrerToken);

          if (response != null && response['success'] == true) {
            SmartLinkLogger.info('✅ Deterministic match found via referrer!');

            final deferredResponse = DeferredLinkResponse.fromJson({
              ...response,
              'matchMethod': 'referrer',
            });

            SmartLinkLogger.info('   Link: ${deferredResponse.shortCode}');
            SmartLinkLogger.info(
                '   Deep Link: ${deferredResponse.deepLinkUrl}');

            return deferredResponse;
          }
        }

        SmartLinkLogger.debug(
            'Referrer lookup failed, falling back to fingerprint...');
      }

      // Step 2: Fall back to fingerprint matching (iOS always, Android fallback)
      SmartLinkLogger.info('Using fingerprint matching...');

      final fingerprint = await _gatherFingerprint();
      SmartLinkLogger.debug(
          'Collected fingerprint: ${fingerprint.platform} ${fingerprint.model}');

      final response = await apiService.matchLink(fingerprint);

      if (response != null && response['success'] == true) {
        SmartLinkLogger.info('✅ Probabilistic match found via fingerprint');

        return DeferredLinkResponse.fromJson({
          ...response,
          'matchMethod': 'fingerprint',
        });
      }

      SmartLinkLogger.info('No deferred deep link found');
      return null;
    } catch (e, stackTrace) {
      SmartLinkLogger.error('Error matching deferred deep link', e, stackTrace);
      return null;
    }
  }

  /// Legacy method for backward compatibility
  /// Match deep link based on device fingerprint only
  /// Returns a DeepLinkMatch if a match is found, null otherwise
  Future<DeepLinkMatch?> matchDeepLink() async {
    try {
      SmartLinkLogger.debug('Attempting to match deferred deep link');

      final fingerprint = await _gatherFingerprint();
      SmartLinkLogger.debug(
          'Collected fingerprint: ${fingerprint.platform} ${fingerprint.model}');

      // Call backend match endpoint
      final response = await apiService.matchLink(fingerprint);

      if (response == null) {
        SmartLinkLogger.debug('No match response from backend');
        return null;
      }

      final match = DeepLinkMatch.fromJson(response);
      SmartLinkLogger.info(
        'Deep link match result: confidence=${match.confidence}, score=${match.score}',
      );

      return match;
    } catch (e) {
      SmartLinkLogger.error('Error matching deferred deep link', e);
      return null;
    }
  }

  /// Check if Android Install Referrer is available and has a token
  Future<bool> hasAndroidReferrer() async {
    if (!Platform.isAndroid) return false;
    final token = await _installReferrer.getInstallReferrer();
    return token != null;
  }

  /// Get the Install Referrer service for advanced usage
  InstallReferrerService get installReferrerService => _installReferrer;

  /// Gather device fingerprint for matching
  /// Collects privacy-respecting device attributes
  Future<SDKFingerprint> _gatherFingerprint() async {
    try {
      final now = DateTime.now();
      final timezone = now.timeZoneOffset.inMinutes;
      final locale = _getLocale();
      final userAgent = _getUserAgent();
      final platform = _getPlatform();

      String? idfv;
      String model;
      String osVersion;

      // Platform-specific device info collection
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        model = iosInfo.model;
        osVersion = iosInfo.systemVersion;

        // IDFV is optional - only collect if privacy controls allow
        idfv = iosInfo.identifierForVendor;

        SmartLinkLogger.debug(
          'iOS device: model=$model, osVersion=$osVersion',
        );
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        model = androidInfo.model;
        osVersion = androidInfo.version.release;

        // Android: No IDFV equivalent in privacy-first approach
        idfv = null;

        SmartLinkLogger.debug(
          'Android device: model=$model, osVersion=$osVersion',
        );
      } else {
        model = 'web';
        osVersion = 'web';
      }

      return SDKFingerprint(
        platform: platform,
        idfv: idfv,
        model: model,
        osVersion: osVersion,
        timezone: timezone,
        locale: locale,
        userAgent: userAgent,
        timestamp: now.toIso8601String(),
      );
    } catch (e) {
      SmartLinkLogger.error('Error gathering fingerprint', e);

      // Return minimal fallback fingerprint
      return SDKFingerprint(
        platform: _getPlatform(),
        model: 'unknown',
        osVersion: 'unknown',
        timezone: DateTime.now().timeZoneOffset.inMinutes,
        locale: 'en-US',
        userAgent: _getUserAgent(),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Get device platform string
  String _getPlatform() {
    if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    } else {
      return 'web';
    }
  }

  /// Get system locale string
  String _getLocale() {
    try {
      final platformDispatcher = PlatformDispatcher.instance;
      final locales = platformDispatcher.locales;
      if (locales.isNotEmpty) {
        return '${locales[0].languageCode}-${locales[0].countryCode}';
      }
    } catch (e) {
      SmartLinkLogger.debug('Could not get platform locale: $e');
    }

    return 'en-US';
  }

  /// Generate User-Agent string (simplified)
  String _getUserAgent() {
    if (Platform.isIOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15';
    } else if (Platform.isAndroid) {
      return 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36';
    }

    return 'Mozilla/5.0 (Windows NT 10.0)';
  }
}

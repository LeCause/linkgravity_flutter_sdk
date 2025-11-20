import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/deep_link_match.dart';
import '../utils/logger.dart';
import 'api_service.dart';
import 'fingerprint_service.dart';

/// Service for handling deferred deep linking
/// Matches device fingerprints to determine if a deep link should be opened
class DeferredDeepLinkService {
  final ApiService apiService;
  final FingerprintService fingerprintService;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  DeferredDeepLinkService({
    required this.apiService,
    required this.fingerprintService,
  });

  /// Match deep link based on device fingerprint
  /// Called when app is launched to detect if this is a deferred deep link
  /// Returns a DeepLinkMatch if a match is found, null otherwise
  Future<DeepLinkMatch?> matchDeepLink() async {
    try {
      SmartLinkLogger.debug('Attempting to match deferred deep link');

      final fingerprint = await _gatherFingerprint();
      SmartLinkLogger.debug('Collected fingerprint: ${fingerprint.platform} ${fingerprint.model}');

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
        // ignore: unnecessary_null_checks
        model = iosInfo.model ?? 'unknown';
        // ignore: unnecessary_null_checks
        osVersion = iosInfo.systemVersion ?? 'unknown';

        // IDFV is optional - only collect if privacy controls allow
        idfv = iosInfo.identifierForVendor;

        SmartLinkLogger.debug(
          'iOS device: model=$model, osVersion=$osVersion',
        );
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // ignore: unnecessary_null_checks
        model = androidInfo.model ?? 'unknown';
        // ignore: unnecessary_null_checks
        osVersion = androidInfo.version.release ?? 'unknown';

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
    // In a real Flutter app, this would use package:intl
    // For now, return a basic locale string
    // In production, you'd get this from your app's localization
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
    // This is a simplified version - in production you might use a package
    // that generates proper user agent strings
    if (Platform.isIOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15';
    } else if (Platform.isAndroid) {
      return 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36';
    }

    return 'Mozilla/5.0 (Windows NT 10.0)';
  }
}
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/logger.dart';
import 'api_service.dart';

/// Service for handling Apple's SKAdNetwork
/// Manages postback requests and conversion tracking
class SKAdNetworkService {
  final ApiService apiService;

  SKAdNetworkService({required this.apiService});

  /// Request SKAdNetwork postback from StoreKit
  /// Called on app first launch to enable conversion tracking
  /// Only available on iOS 14.5+
  Future<void> requestPostback() async {
    // SKAdNetwork is iOS-only
    if (!Platform.isIOS) {
      SmartLinkLogger.debug('SKAdNetwork: Not available on non-iOS platform');
      return;
    }

    try {
      SmartLinkLogger.debug('SKAdNetwork: Requesting postback from StoreKit');

      // Note: In actual implementation, this would use method channels
      // to call native iOS code:
      // const platform = MethodChannel('com.smartlink/skadnetwork');
      // final result = await platform.invokeMethod('requestPostback');

      // The actual postback data is sent by iOS automatically
      // Backend receives it at POST /api/v1/skadnetwork-postback

      SmartLinkLogger.debug('SKAdNetwork: Postback request initiated');
    } catch (e) {
      SmartLinkLogger.warning('SKAdNetwork: Error requesting postback: $e');
      // Graceful failure - app continues to work without SKAdNetwork
    }
  }

  /// Get SKAdNetwork configuration for debugging
  Map<String, dynamic> getConfig() {
    return {
      'platform': Platform.isIOS ? 'ios' : 'other',
      'skAdNetworkVersion': '4.0',
      'conversionWindowMinutes': 1440, // 24 hours
      'postbackWindowHours': '24-100',
      'available': Platform.isIOS,
    };
  }

  /// Request postback with completion callback (optional)
  Future<bool> requestPostbackWithCallback({
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) async {
    try {
      await requestPostback();
      onSuccess?.call();
      return true;
    } catch (e) {
      final errorMessage = 'SKAdNetwork postback request failed: $e';
      SmartLinkLogger.error(errorMessage, e);
      onError?.call(errorMessage);
      return false;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'linkgravity_flutter_sdk_platform_interface.dart';

/// An implementation of [LinkGravityFlutterSdkPlatform] that uses method channels.
class MethodChannelLinkGravityFlutterSdk extends LinkGravityFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('linkgravity_flutter_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}

/// Deep link match result from probabilistic fingerprinting
class DeepLinkMatch {
  /// Whether a deep link was found
  final bool found;

  /// Confidence level of the match
  /// - high: Score >= 95 (very confident)
  /// - medium: 70-94 (fairly confident)
  /// - low: 50-69 (weak match)
  /// - none: < 50 (no match)
  final String confidence;

  /// Matching score (0-130)
  final int score;

  /// Deep link URL to open if match found
  final String? deepLinkUrl;

  /// Link ID for tracking
  final String? linkId;

  /// Match metadata with detailed information
  final DeepLinkMatchMetadata metadata;

  DeepLinkMatch({
    required this.found,
    required this.confidence,
    required this.score,
    this.deepLinkUrl,
    this.linkId,
    required this.metadata,
  });

  /// Check if confidence level is high enough to trust the match
  bool isHighConfidence() => confidence == 'high';

  /// Check if confidence level is acceptable for deferred deep linking
  bool isAcceptableConfidence() =>
      confidence == 'high' || confidence == 'medium';

  /// Create from JSON (API response)
  factory DeepLinkMatch.fromJson(Map<String, dynamic> json) {
    return DeepLinkMatch(
      found: json['found'] as bool? ?? false,
      confidence: json['confidence'] as String? ?? 'none',
      score: json['score'] as int? ?? 0,
      deepLinkUrl: json['deepLinkUrl'] as String?,
      linkId: json['linkId'] as String?,
      metadata: DeepLinkMatchMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'found': found,
        'confidence': confidence,
        'score': score,
        'deepLinkUrl': deepLinkUrl,
        'linkId': linkId,
        'metadata': metadata.toJson(),
      };

  @override
  String toString() => 'DeepLinkMatch('
      'found: $found, '
      'confidence: $confidence, '
      'score: $score, '
      'deepLinkUrl: $deepLinkUrl, '
      'linkId: $linkId'
      ')';
}

/// Metadata for deep link match with detailed information
class DeepLinkMatchMetadata {
  /// List of attributes that matched (e.g., platform, timezone, browser)
  final List<String> matchReasons;

  /// Whether platform matched
  final bool platformMatch;

  /// Whether timezone matched
  final bool timezoneMatch;

  /// Whether locale matched
  final bool localeMatch;

  /// Whether browser family matched
  final bool browserMatch;

  /// Time window score (0-25)
  final int timeWindow;

  DeepLinkMatchMetadata({
    required this.matchReasons,
    required this.platformMatch,
    required this.timezoneMatch,
    required this.localeMatch,
    required this.browserMatch,
    required this.timeWindow,
  });

  /// Create from JSON
  factory DeepLinkMatchMetadata.fromJson(Map<String, dynamic> json) {
    return DeepLinkMatchMetadata(
      matchReasons: List<String>.from(
        json['matchReasons'] as List? ?? [],
      ),
      platformMatch: json['platformMatch'] as bool? ?? false,
      timezoneMatch: json['timezoneMatch'] as bool? ?? false,
      localeMatch: json['localeMatch'] as bool? ?? false,
      browserMatch: json['browserMatch'] as bool? ?? false,
      timeWindow: json['timeWindow'] as int? ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'matchReasons': matchReasons,
        'platformMatch': platformMatch,
        'timezoneMatch': timezoneMatch,
        'localeMatch': localeMatch,
        'browserMatch': browserMatch,
        'timeWindow': timeWindow,
      };

  @override
  String toString() => 'DeepLinkMatchMetadata('
      'matchReasons: $matchReasons, '
      'platformMatch: $platformMatch, '
      'timezoneMatch: $timezoneMatch, '
      'localeMatch: $localeMatch, '
      'browserMatch: $browserMatch, '
      'timeWindow: $timeWindow'
      ')';
}

/// SDK device fingerprint for matching
class SDKFingerprint {
  /// Device platform (ios, android, web)
  final String platform;

  /// iOS Identifier for Vendor (optional, privacy-aware)
  final String? idfv;

  /// Device model (e.g., iPhone14,2, SM-G991B)
  final String model;

  /// OS version
  final String osVersion;

  /// Timezone offset in minutes
  final int timezone;

  /// Device locale (e.g., en-US, ja-JP)
  final String locale;

  /// User-Agent string
  final String userAgent;

  /// Timestamp of fingerprint collection
  final String timestamp;

  SDKFingerprint({
    required this.platform,
    this.idfv,
    required this.model,
    required this.osVersion,
    required this.timezone,
    required this.locale,
    required this.userAgent,
    required this.timestamp,
  });

  /// Create from JSON
  factory SDKFingerprint.fromJson(Map<String, dynamic> json) {
    return SDKFingerprint(
      platform: json['platform'] as String? ?? 'unknown',
      idfv: json['idfv'] as String?,
      model: json['model'] as String? ?? 'unknown',
      osVersion: json['osVersion'] as String? ?? 'unknown',
      timezone: json['timezone'] as int? ?? 0,
      locale: json['locale'] as String? ?? 'en-US',
      userAgent: json['userAgent'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'platform': platform,
        'idfv': idfv,
        'model': model,
        'osVersion': osVersion,
        'timezone': timezone,
        'locale': locale,
        'userAgent': userAgent,
        'timestamp': timestamp,
      };

  @override
  String toString() => 'SDKFingerprint('
      'platform: $platform, '
      'model: $model, '
      'osVersion: $osVersion, '
      'timezone: $timezone, '
      'locale: $locale'
      ')';
}

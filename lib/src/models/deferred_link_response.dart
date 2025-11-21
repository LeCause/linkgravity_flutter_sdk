/// Response from deferred link lookup endpoints
///
/// This model represents the response from both:
/// - GET /api/v1/sdk/deferred-link (fingerprint matching)
/// - GET /api/v1/sdk/deferred-link/referrer/:token (Android referrer matching)
class DeferredLinkResponse {
  /// Whether the lookup was successful
  final bool success;

  /// Whether this link has already been claimed
  final bool? alreadyClaimed;

  /// When the link was claimed (if already claimed)
  final DateTime? claimedAt;

  /// Deep link data containing URL, path, and parameters
  final Map<String, dynamic>? deepLinkData;

  /// The link ID for tracking
  final String? linkId;

  /// Short code of the link
  final String? shortCode;

  /// Platform that was matched (android, ios)
  final String? platform;

  /// How the match was made: "referrer" (deterministic) or "fingerprint" (probabilistic)
  final String? matchMethod;

  /// Confidence level for fingerprint matching
  final String? confidence;

  /// Numeric score for fingerprint matching
  final int? score;

  DeferredLinkResponse({
    required this.success,
    this.alreadyClaimed,
    this.claimedAt,
    this.deepLinkData,
    this.linkId,
    this.shortCode,
    this.platform,
    this.matchMethod,
    this.confidence,
    this.score,
  });

  /// Create from JSON (API response)
  factory DeferredLinkResponse.fromJson(Map<String, dynamic> json) {
    return DeferredLinkResponse(
      success: json['success'] ?? false,
      alreadyClaimed: json['alreadyClaimed'],
      claimedAt:
          json['claimedAt'] != null ? DateTime.parse(json['claimedAt']) : null,
      deepLinkData: json['deepLinkData'] as Map<String, dynamic>?,
      linkId: json['linkId'] as String?,
      shortCode: json['shortCode'] as String?,
      platform: json['platform'] as String?,
      matchMethod: json['matchMethod'] as String?,
      confidence: json['confidence'] as String?,
      score: json['score'] as int?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'success': success,
        if (alreadyClaimed != null) 'alreadyClaimed': alreadyClaimed,
        if (claimedAt != null) 'claimedAt': claimedAt!.toIso8601String(),
        if (deepLinkData != null) 'deepLinkData': deepLinkData,
        if (linkId != null) 'linkId': linkId,
        if (shortCode != null) 'shortCode': shortCode,
        if (platform != null) 'platform': platform,
        if (matchMethod != null) 'matchMethod': matchMethod,
        if (confidence != null) 'confidence': confidence,
        if (score != null) 'score': score,
      };

  /// Get deep link URL from data
  String? get deepLinkUrl => deepLinkData?['deepLinkUrl'] as String?;

  /// Get deep link path
  String? get path => deepLinkData?['path'] as String?;

  /// Get deep link parameters
  Map<String, dynamic>? get params =>
      deepLinkData?['params'] as Map<String, dynamic>?;

  /// Check if this was a deterministic match (Android referrer)
  bool get isDeterministic => matchMethod == 'referrer';

  /// Check if this was a probabilistic match (fingerprint)
  bool get isProbabilistic => matchMethod == 'fingerprint';

  /// Check if confidence level is acceptable for deferred deep linking
  bool isAcceptableConfidence() {
    if (isDeterministic) return true; // Referrer match is always reliable
    return confidence == 'high' || confidence == 'medium';
  }

  @override
  String toString() => 'DeferredLinkResponse('
      'success: $success, '
      'matchMethod: $matchMethod, '
      'linkId: $linkId, '
      'deepLinkUrl: $deepLinkUrl'
      ')';
}

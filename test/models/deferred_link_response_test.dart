import 'package:flutter_test/flutter_test.dart';
import 'package:linkgravity_flutter_sdk/src/models/deferred_link_response.dart';

void main() {
  group('DeferredLinkResponse Parsing', () {
    test('should parse wrapped response from backend', () {
      final json = {
        'success': true,
        'match': {
          'linkId': 'link-123',
          'shortCode': 'abc123',
          'platform': 'android',
          'matchMethod': 'referrer',
          'deepLinkData': {
            'deepLinkUrl': 'myapp://example.com/page',
            'path': '/page',
            'params': {'ref': 'campaign'},
          },
        },
      };

      final response = DeferredLinkResponse.fromJson(json);

      expect(response.success, true);
      expect(response.linkId, 'link-123');
      expect(response.shortCode, 'abc123');
      expect(response.platform, 'android');
      expect(response.matchMethod, 'referrer');
      expect(response.deepLinkUrl, 'myapp://example.com/page');
      expect(response.path, '/page');
      expect(response.params?['ref'], 'campaign');
    });

    test('should parse flat response (backward compatible)', () {
      final json = {
        'linkId': 'link-456',
        'shortCode': 'def456',
        'matchMethod': 'fingerprint',
        'confidence': 'high',
        'score': 95,
        'deepLinkData': {
          'deepLinkUrl': 'myapp://example.com/product',
          'path': '/product',
          'params': {},
        },
      };

      final response = DeferredLinkResponse.fromJson(json);

      expect(response.linkId, 'link-456');
      expect(response.shortCode, 'def456');
      expect(response.matchMethod, 'fingerprint');
      expect(response.confidence, 'high');
      expect(response.score, 95);
      expect(response.deepLinkUrl, 'myapp://example.com/product');
    });

    test('should handle wrapped response with no match', () {
      final json = {
        'success': false,
        'match': null,
      };

      final response = DeferredLinkResponse.fromJson(json);

      expect(response.success, false);
      expect(response.deepLinkUrl, isNull);
    });

    test('should extract default success value from wrapped response', () {
      final json = {
        'success': true,
        'match': {
          'linkId': 'link-789',
          'deepLinkData': {
            'deepLinkUrl': 'myapp://example.com/test',
          },
        },
      };

      final response = DeferredLinkResponse.fromJson(json);

      expect(response.success, true);
    });

    test('should handle missing optional fields in wrapped response', () {
      final json = {
        'success': true,
        'match': {
          'linkId': 'link-000',
        },
      };

      final response = DeferredLinkResponse.fromJson(json);

      expect(response.success, true);
      expect(response.linkId, 'link-000');
      expect(response.platform, isNull);
      expect(response.confidence, isNull);
    });

    test('should correctly identify deterministic vs probabilistic matches', () {
      // Deterministic (referrer)
      final deterministicJson = {
        'success': true,
        'match': {
          'linkId': 'link-123',
          'matchMethod': 'referrer',
        },
      };

      final deterministicResponse =
          DeferredLinkResponse.fromJson(deterministicJson);

      expect(deterministicResponse.isDeterministic, true);
      expect(deterministicResponse.isProbabilistic, false);

      // Probabilistic (fingerprint)
      final probabilisticJson = {
        'success': true,
        'match': {
          'linkId': 'link-456',
          'matchMethod': 'fingerprint',
          'confidence': 'high',
        },
      };

      final probabilisticResponse =
          DeferredLinkResponse.fromJson(probabilisticJson);

      expect(probabilisticResponse.isDeterministic, false);
      expect(probabilisticResponse.isProbabilistic, true);
    });

    test('should correctly assess acceptable confidence levels', () {
      // High confidence - acceptable
      final highConfidenceJson = {
        'success': true,
        'match': {
          'linkId': 'link-1',
          'matchMethod': 'fingerprint',
          'confidence': 'high',
        },
      };

      expect(
        DeferredLinkResponse.fromJson(highConfidenceJson)
            .isAcceptableConfidence(),
        true,
      );

      // Medium confidence - acceptable
      final mediumConfidenceJson = {
        'success': true,
        'match': {
          'linkId': 'link-2',
          'matchMethod': 'fingerprint',
          'confidence': 'medium',
        },
      };

      expect(
        DeferredLinkResponse.fromJson(mediumConfidenceJson)
            .isAcceptableConfidence(),
        true,
      );

      // Low confidence - not acceptable
      final lowConfidenceJson = {
        'success': true,
        'match': {
          'linkId': 'link-3',
          'matchMethod': 'fingerprint',
          'confidence': 'low',
        },
      };

      expect(
        DeferredLinkResponse.fromJson(lowConfidenceJson)
            .isAcceptableConfidence(),
        false,
      );

      // Referrer (deterministic) - always acceptable
      final referrerJson = {
        'success': true,
        'match': {
          'linkId': 'link-4',
          'matchMethod': 'referrer',
        },
      };

      expect(
        DeferredLinkResponse.fromJson(referrerJson).isAcceptableConfidence(),
        true,
      );
    });

    test('should handle response with claimed info', () {
      final json = {
        'success': true,
        'match': {
          'linkId': 'link-123',
          'alreadyClaimed': true,
          'claimedAt': '2025-11-21T10:00:00.000Z',
          'deepLinkData': {
            'deepLinkUrl': 'myapp://example.com/page',
          },
        },
      };

      final response = DeferredLinkResponse.fromJson(json);

      expect(response.alreadyClaimed, true);
      expect(response.claimedAt, isNotNull);
    });

    test('should serialize to JSON correctly', () {
      final response = DeferredLinkResponse(
        success: true,
        linkId: 'link-123',
        shortCode: 'abc123',
        matchMethod: 'fingerprint',
        confidence: 'high',
        score: 90,
        deepLinkData: {
          'deepLinkUrl': 'myapp://example.com/page',
          'path': '/page',
        },
      );

      final json = response.toJson();

      expect(json['success'], true);
      expect(json['linkId'], 'link-123');
      expect(json['matchMethod'], 'fingerprint');
      expect(json['confidence'], 'high');
      expect(json['score'], 90);
    });
  });
}

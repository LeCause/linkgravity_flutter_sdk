/// FlutterFlow Custom Action: attachSmartLinkListener
///
/// This is a complete example showing how to set up deep link routing
/// in your FlutterFlow app using the SmartLink SDK's route registration.
///
/// ## Setup Instructions:
///
/// 1. Add this as a Custom Action in FlutterFlow
/// 2. Call it on your first page's "On Page Load" trigger
/// 3. Customize the routes map below to match your app's navigation
///
/// ## Usage in FlutterFlow:
///
/// - **Action Name**: attachSmartLinkListener
/// - **Return Type**: Future<void>
/// - **Arguments**: BuildContext context
/// - **When to Call**: First page → On Page Load
///
/// ## Features:
///
/// - ✅ Handles both cold start (app opened via link) and warm start (link tapped while app running)
/// - ✅ Automatically uses scheduleMicrotask to prevent navigation errors
/// - ✅ Supports simple route mapping with RouteAction.goNamed()
/// - ✅ Supports advanced logic with RouteAction.custom()
/// - ✅ No manual stream subscription needed
/// - ✅ No need to check initialDeepLink manually
///
library flutterflow_smartlink_listener;

// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart';
import '/flutter_flow/custom_functions.dart';
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';

/// Attach SmartLink deep link listener and register routes
///
/// Call this in your first page's "On Page Load" trigger.
///
/// This function:
/// 1. Registers all your deep link routes
/// 2. Automatically handles initial deep link (cold start)
/// 3. Sets up listener for incoming deep links (warm start)
/// 4. Executes navigation when routes match
Future<void> attachSmartLinkListener(BuildContext context) async {
  try {
    // Register all deep link routes
    SmartLinkClient.instance.registerRoutes(
      context: context,
      routes: {
        // =====================================================================
        // SIMPLE ROUTE MAPPING
        // =====================================================================

        // Example 1: Route to a specific page with parameters
        '/hidden': (deepLink) => RouteAction.goNamed(
          'HiddenDeepLinkPage',
          extra: {
            'ref': deepLink.getParam('ref'),
          },
        ),

        // Example 2: Same handler for multiple routes
        '/secret': (deepLink) => RouteAction.goNamed(
          'HiddenDeepLinkPage',
          extra: {
            'ref': deepLink.getParam('ref'),
          },
        ),

        // Example 3: Route with path and query parameters
        '/profile': (deepLink) => RouteAction.goNamed(
          'ProfilePage',
          pathParameters: {
            'userId': deepLink.getParam('userId') ?? '',
          },
          queryParameters: {
            'source': 'deeplink',
          },
          extra: {
            'utm_campaign': deepLink.utm?.campaign,
          },
        ),

        // =====================================================================
        // ADVANCED CUSTOM HANDLERS
        // =====================================================================

        // Example 4: Custom handler with conditional logic
        '/product': (deepLink) => RouteAction.custom((ctx) {
          // Extract product ID from path (e.g., /product/123)
          final productId = deepLink.path.split('/').last;
          final category = deepLink.getParam('category');

          if (productId.isNotEmpty && productId != 'product') {
            // Navigate to product details
            ctx.pushNamed(
              'ProductDetails',
              extra: {
                'id': productId,
                'category': category,
                'source': 'smartlink',
              },
            );
          } else {
            // Fallback to product catalog
            ctx.goNamed('ProductCatalog');
          }
        }),

        // Example 5: Custom handler with analytics tracking
        '/promo': (deepLink) => RouteAction.custom((ctx) {
          final promoCode = deepLink.getParam('code');
          final utmCampaign = deepLink.utm?.campaign;

          // Track promo view event
          SmartLinkClient.instance.trackEvent('promo_viewed', {
            'code': promoCode,
            'campaign': utmCampaign,
          });

          // Navigate based on promo type
          if (promoCode?.startsWith('VIP') ?? false) {
            ctx.goNamed('VIPPromoPage', extra: {'code': promoCode});
          } else {
            ctx.goNamed('StandardPromoPage', extra: {'code': promoCode});
          }
        }),

        // Example 6: Custom handler with user authentication check
        '/dashboard': (deepLink) => RouteAction.custom((ctx) {
          // Check if user is authenticated (replace with your auth logic)
          // final isAuthenticated = FFAppState().isLoggedIn;

          // For demo purposes:
          final isAuthenticated = true;

          if (isAuthenticated) {
            ctx.goNamed('DashboardPage');
          } else {
            // Redirect to login, preserve deep link for after login
            ctx.goNamed(
              'LoginPage',
              extra: {
                'redirect': deepLink.path,
              },
            );
          }
        }),

        // Example 7: Custom handler with data fetching
        '/article': (deepLink) => RouteAction.custom((ctx) async {
          final articleId = deepLink.getParam('id');

          if (articleId != null) {
            // You could fetch article data here if needed
            // final article = await fetchArticle(articleId);

            ctx.pushNamed(
              'ArticlePage',
              extra: {
                'articleId': articleId,
                'utm_source': deepLink.utm?.source,
              },
            );
          }
        }),

        // =====================================================================
        // FALLBACK / DEFAULT ROUTE
        // =====================================================================

        // Example 8: Catch-all for unmatched routes (put this last)
        // Note: This only works if matchPrefix=false is set
        // '/': (deepLink) => RouteAction.goNamed('HomePage'),
      },
    );

    print('✅ SmartLink routes registered successfully');
  } catch (e) {
    print('❌ Failed to register SmartLink routes: $e');
  }
}

// ============================================================================
// CUSTOMIZATION GUIDE
// ============================================================================
//
// To customize this for your app:
//
// 1. Replace route patterns (e.g., '/hidden', '/product') with your routes
// 2. Replace page names (e.g., 'HiddenDeepLinkPage') with your FlutterFlow page names
// 3. Map deep link parameters to your page's expected data structure
// 4. Add analytics tracking as needed
// 5. Add authentication checks for protected routes
//
// ============================================================================
// ROUTE MATCHING
// ============================================================================
//
// By default, routes match by PREFIX:
// - Pattern '/product' matches '/product', '/product/123', '/product/123/details'
//
// To use EXACT matching instead, set matchPrefix: false:
//
// SmartLinkClient.instance.registerRoutes(
//   context: context,
//   matchPrefix: false, // <-- Exact match only
//   routes: { ... },
// );
//
// ============================================================================
// TESTING
// ============================================================================
//
// To test deep links:
//
// 1. iOS Simulator:
//    xcrun simctl openurl booted "your-scheme://hidden?ref=test"
//
// 2. Android Emulator:
//    adb shell am start -a android.intent.action.VIEW -d "your-scheme://hidden?ref=test"
//
// 3. Physical Device (via ADB):
//    adb shell am start -a android.intent.action.VIEW -d "https://your-domain.com/hidden?ref=test"
//
// ============================================================================

# FlutterFlow Implementation Guide

This guide shows you how to integrate the LinkGravity Flutter SDK into your FlutterFlow project with deep link routing.

## Table of Contents

- [Quick Start](#quick-start)
- [Simple Route Registration (Recommended)](#simple-route-registration-recommended)
- [Custom Route Registration (Advanced)](#custom-route-registration-advanced)
- [Mixed Mode (Simple + Custom)](#mixed-mode-simple--custom)
- [Complete Examples](#complete-examples)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### 1. Add Package Dependency

In your FlutterFlow project:
1. Go to **Settings & Integrations** > **Dependencies**
2. Add the package:
   ```yaml
   linkgravity_flutter_sdk: ^1.0.0
   ```

### 2. Create Custom Action

Create a new Custom Action called `initLinkGravityWithRoutes`:

```dart
// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

// Import LinkGravity SDK
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

Future initLinkGravityWithRoutes(BuildContext context) async {
  // 1. Initialize SDK
  await LinkGravityClient.initialize(
    baseUrl: 'https://your-backend-url.com',
    apiKey: 'your-api-key',
    config: LinkGravityConfig(
      enableAnalytics: true,
      enableDeepLinking: true,
      logLevel: LogLevel.debug,
    ),
  );

  // 2. Register routes (see examples below)
  LinkGravityClient.instance.registerRoutes(
    context: context,
    routes: {
      '/product': 'ProductDetailsPage',
      '/profile': 'UserProfilePage',
    },
  );
}
```

### 3. Call on App Start

In your **App Settings**:
1. Go to **App State** > **On App Start**
2. Add action: **Custom Action** > `initLinkGravityWithRoutes`

---

## Simple Route Registration (Recommended)

**Use this when:** You just want to navigate to a page and pass all deep link parameters automatically.

### Basic Example

```dart
Future initLinkGravityWithRoutes(BuildContext context) async {
  await LinkGravityClient.initialize(
    baseUrl: 'https://your-backend-url.com',
    apiKey: 'your-api-key',
    config: LinkGravityConfig(
      enableAnalytics: true,
      enableDeepLinking: true,
      logLevel: LogLevel.info,
    ),
  );

  // Simple string-based routing
  LinkGravityClient.instance.registerRoutes(
    context: context,
    routes: {
      // Deep link path -> FlutterFlow page name
      '/product': 'ProductDetailsPage',
      '/profile': 'UserProfilePage',
      '/settings': 'SettingsPage',
      '/hidden': 'HiddenDeepLinkPage',
    },
  );
}
```

### How It Works

When a user clicks a deep link like:
```
https://your-app.com/product?id=123&ref=campaign
```

The SDK will:
1. Match the path `/product` to `'ProductDetailsPage'`
2. Automatically call `context.goNamed('ProductDetailsPage', extra: {'id': '123', 'ref': 'campaign'})`
3. Navigate to the page with all parameters passed as `extra`

### Accessing Parameters in FlutterFlow

In your target page (e.g., `ProductDetailsPage`):

1. Add **Page Parameters**:
   - Go to your page settings
   - Add parameters: `id`, `ref`, etc.
   - Set type: `String`

2. The parameters will be automatically available in your page widgets!

---

## Custom Route Registration (Advanced)

**Use this when:** You need custom logic before navigation (validation, analytics, conditional routing, etc.)

### Example with Validation

```dart
Future initLinkGravityWithRoutes(BuildContext context) async {
  await LinkGravityClient.initialize(
    baseUrl: 'https://your-backend-url.com',
    apiKey: 'your-api-key',
    config: LinkGravityConfig(
      enableAnalytics: true,
      enableDeepLinking: true,
      logLevel: LogLevel.debug,
    ),
  );

  LinkGravityClient.instance.registerRoutes(
    context: context,
    routes: {
      '/product': (deepLink) => RouteAction((ctx, data) {
        // Custom validation
        final productId = data.getParam('id');

        if (productId == null || productId.isEmpty) {
          // Navigate to error page if invalid
          ctx.goNamed('ErrorPage', extra: {
            'message': 'Product ID is required'
          });
          return;
        }

        // Navigate to product page
        ctx.goNamed('ProductDetailsPage', extra: {
          'id': productId,
          'ref': data.getParam('ref'),
        });
      }),
    },
  );
}
```

### Example with Analytics

```dart
LinkGravityClient.instance.registerRoutes(
  context: context,
  routes: {
    '/special-offer': (deepLink) => RouteAction((ctx, data) {
      // Track custom event
      LinkGravityClient.instance.trackEvent('special_offer_opened', {
        'campaign': data.getParam('campaign'),
        'source': data.getParam('utm_source'),
      });

      // Navigate to page
      ctx.goNamed('SpecialOfferPage', extra: data.params);
    }),
  },
);
```

### Example with Conditional Routing

```dart
LinkGravityClient.instance.registerRoutes(
  context: context,
  routes: {
    '/content': (deepLink) => RouteAction((ctx, data) {
      final contentType = data.getParam('type');

      // Route to different pages based on parameter
      if (contentType == 'video') {
        ctx.goNamed('VideoPlayerPage', extra: {
          'videoId': data.getParam('id')
        });
      } else if (contentType == 'article') {
        ctx.goNamed('ArticlePage', extra: {
          'articleId': data.getParam('id')
        });
      } else {
        ctx.goNamed('HomePage');
      }
    }),
  },
);
```

### Example with Parameter Transformation

```dart
LinkGravityClient.instance.registerRoutes(
  context: context,
  routes: {
    '/user': (deepLink) => RouteAction((ctx, data) {
      // Transform parameters before navigation
      final userId = data.getParam('id');
      final userName = data.getParam('name');

      ctx.goNamed('UserProfilePage', extra: {
        'userId': userId,
        'displayName': userName?.toUpperCase() ?? 'Anonymous',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }),
  },
);
```

---

## Mixed Mode (Simple + Custom)

You can combine both approaches in the same registration:

```dart
Future initLinkGravityWithRoutes(BuildContext context) async {
  await LinkGravityClient.initialize(
    baseUrl: 'https://your-backend-url.com',
    apiKey: 'your-api-key',
    config: LinkGravityConfig(
      enableAnalytics: true,
      enableDeepLinking: true,
    ),
  );

  LinkGravityClient.instance.registerRoutes(
    context: context,
    routes: {
      // Simple routes (most common)
      '/profile': 'UserProfilePage',
      '/settings': 'SettingsPage',
      '/about': 'AboutPage',

      // Custom routes (need special handling)
      '/product': (deepLink) => RouteAction((ctx, data) {
        final id = data.getParam('id');
        if (id == null) {
          ctx.goNamed('ErrorPage');
          return;
        }
        ctx.goNamed('ProductDetailsPage', extra: {'id': id});
      }),

      '/checkout': (deepLink) => RouteAction((ctx, data) {
        // Track conversion event
        LinkGravityClient.instance.trackEvent('checkout_started');

        ctx.goNamed('CheckoutPage', extra: data.params);
      }),
    },
  );
}
```

---

## Complete Examples

### Example 1: E-commerce App

```dart
Future initLinkGravityWithRoutes(BuildContext context) async {
  await LinkGravityClient.initialize(
    baseUrl: 'https://api.myshop.com',
    apiKey: 'pk_live_abc123',
    config: LinkGravityConfig(
      enableAnalytics: true,
      enableDeepLinking: true,
      logLevel: LogLevel.info,
    ),
  );

  LinkGravityClient.instance.registerRoutes(
    context: context,
    routes: {
      // Simple product pages
      '/product': 'ProductDetailsPage',
      '/category': 'CategoryPage',
      '/cart': 'ShoppingCartPage',

      // Special offer with tracking
      '/offer': (deepLink) => RouteAction((ctx, data) {
        LinkGravityClient.instance.trackEvent('offer_clicked', {
          'offerId': data.getParam('id'),
          'campaign': data.getParam('campaign'),
        });

        ctx.goNamed('OfferPage', extra: data.params);
      }),

      // Checkout with validation
      '/checkout': (deepLink) => RouteAction((ctx, data) {
        // Check if user is logged in (example)
        final isLoggedIn = FFAppState().isUserLoggedIn;

        if (!isLoggedIn) {
          ctx.goNamed('LoginPage', extra: {
            'redirectTo': 'CheckoutPage'
          });
          return;
        }

        ctx.goNamed('CheckoutPage', extra: data.params);
      }),
    },
  );
}
```

### Example 2: Content App

```dart
Future initLinkGravityWithRoutes(BuildContext context) async {
  await LinkGravityClient.initialize(
    baseUrl: 'https://api.mycontent.com',
    apiKey: 'pk_live_xyz789',
    config: LinkGravityConfig(
      enableAnalytics: true,
      enableDeepLinking: true,
    ),
  );

  LinkGravityClient.instance.registerRoutes(
    context: context,
    routes: {
      // Simple content pages
      '/article': 'ArticlePage',
      '/video': 'VideoPlayerPage',
      '/author': 'AuthorProfilePage',

      // Dynamic content routing
      '/content': (deepLink) => RouteAction((ctx, data) {
        final type = data.getParam('type');
        final id = data.getParam('id');

        switch (type) {
          case 'article':
            ctx.goNamed('ArticlePage', extra: {'articleId': id});
            break;
          case 'video':
            ctx.goNamed('VideoPlayerPage', extra: {'videoId': id});
            break;
          case 'podcast':
            ctx.goNamed('PodcastPlayerPage', extra: {'podcastId': id});
            break;
          default:
            ctx.goNamed('HomePage');
        }
      }),

      // Premium content with paywall check
      '/premium': (deepLink) => RouteAction((ctx, data) {
        final isPremium = FFAppState().userIsPremium;

        if (!isPremium) {
          ctx.goNamed('PaywallPage', extra: {
            'returnTo': '/premium',
            'contentId': data.getParam('id'),
          });
          return;
        }

        ctx.goNamed('PremiumContentPage', extra: data.params);
      }),
    },
  );
}
```

### Example 3: Social App

```dart
Future initLinkGravityWithRoutes(BuildContext context) async {
  await LinkGravityClient.initialize(
    baseUrl: 'https://api.mysocial.com',
    apiKey: 'pk_live_social123',
    config: LinkGravityConfig(
      enableAnalytics: true,
      enableDeepLinking: true,
    ),
  );

  LinkGravityClient.instance.registerRoutes(
    context: context,
    routes: {
      // Simple profile and post pages
      '/profile': 'UserProfilePage',
      '/post': 'PostDetailsPage',
      '/feed': 'FeedPage',

      // Share with tracking
      '/share': (deepLink) => RouteAction((ctx, data) {
        final postId = data.getParam('postId');
        final sharedBy = data.getParam('sharedBy');

        // Track share event
        LinkGravityClient.instance.trackEvent('post_shared', {
          'postId': postId,
          'sharedBy': sharedBy,
        });

        ctx.goNamed('PostDetailsPage', extra: {
          'id': postId,
          'highlightShare': 'true',
        });
      }),

      // Referral with conversion tracking
      '/invite': (deepLink) => RouteAction((ctx, data) {
        final referrerId = data.getParam('ref');

        // Save referrer to app state
        FFAppState().update(() {
          FFAppState().referrerId = referrerId;
        });

        // Track referral
        LinkGravityClient.instance.trackEvent('referral_clicked', {
          'referrerId': referrerId,
        });

        ctx.goNamed('SignupPage', extra: {
          'referralCode': referrerId,
        });
      }),
    },
  );
}
```

---

## Troubleshooting

### Routes Not Matching

**Problem:** Deep links open the app but don't navigate

**Solution:**
1. Check that `registerRoutes` is called AFTER `initialize`
2. Verify route paths match exactly (case-sensitive)
3. Enable debug logging:
   ```dart
   config: LinkGravityConfig(
     logLevel: LogLevel.debug,
   )
   ```
4. Check console logs for route matching messages

### Parameters Not Passed

**Problem:** Page opens but parameters are missing

**Solution:**
1. Verify page parameters are defined in FlutterFlow page settings
2. Check parameter names match exactly
3. For simple mode, parameters are passed as `extra` automatically
4. For custom mode, ensure you're passing `data.params` or specific parameters

### Context Errors

**Problem:** "goNamed not found" or context errors

**Solution:**
1. Ensure you're passing the correct `BuildContext` from your page
2. For custom actions, the context parameter must be of type `BuildContext`
3. If using custom RouteAction, use `ctx` (the provided context) not the outer `context`

### Navigation Happens Twice

**Problem:** App navigates to the same page twice

**Solution:**
1. The SDK automatically handles initial deep links
2. Don't manually check for deep links in your pages
3. Only call `registerRoutes` once in your app lifecycle

---

## Best Practices

### 1. Use Simple Mode When Possible
```dart
// ✅ Good - Simple and clear
'/profile': 'UserProfilePage',

// ❌ Avoid unnecessary complexity
'/profile': (deepLink) => RouteAction((ctx, data) {
  ctx.goNamed('UserProfilePage', extra: data.params);
}),
```

### 2. Validate Required Parameters
```dart
// ✅ Good - Validate before navigation
'/product': (deepLink) => RouteAction((ctx, data) {
  final id = data.getParam('id');
  if (id == null) {
    ctx.goNamed('ErrorPage');
    return;
  }
  ctx.goNamed('ProductPage', extra: {'id': id});
}),
```

### 3. Track Important Events
```dart
// ✅ Good - Track conversions and key events
'/checkout': (deepLink) => RouteAction((ctx, data) {
  LinkGravityClient.instance.trackEvent('checkout_started');
  ctx.goNamed('CheckoutPage', extra: data.params);
}),
```

### 4. Handle Authentication
```dart
// ✅ Good - Redirect to login if needed
'/premium': (deepLink) => RouteAction((ctx, data) {
  if (!FFAppState().isLoggedIn) {
    ctx.goNamed('LoginPage', extra: {'returnTo': '/premium'});
    return;
  }
  ctx.goNamed('PremiumPage', extra: data.params);
}),
```

### 5. Use Descriptive Route Patterns
```dart
// ✅ Good - Clear and SEO-friendly
'/product': 'ProductDetailsPage',
'/category': 'CategoryPage',
'/user/profile': 'UserProfilePage',

// ❌ Avoid - Unclear purpose
'/p': 'ProductDetailsPage',
'/c': 'CategoryPage',
'/up': 'UserProfilePage',
```

---

## Need Help?

- **Documentation:** Check the main [README.md](README.md)
- **Examples:** See complete examples in [examples/](examples/)
- **Issues:** Report bugs at [GitHub Issues](https://github.com/your-repo/issues)
- **FlutterFlow Docs:** [FlutterFlow Custom Actions](https://docs.flutterflow.io/actions/custom-actions)

---

## What's Next?

- Learn about [Analytics Tracking](README.md#analytics)
- Understand [Deferred Deep Linking](README.md#deferred-deep-linking)
- Explore [Attribution](README.md#attribution)
- See [Advanced Configuration](README.md#configuration)

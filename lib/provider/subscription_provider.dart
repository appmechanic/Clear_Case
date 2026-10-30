import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/static/subscription_config.dart';
import '../core/utils/helping_functions.dart';
import '../services/notification_service.dart';

/// One purchasable plan as shown on the paywall.
class SubscriptionPlan {
  /// Null for a display-only plan built from [SubscriptionConfig]'s fallback
  /// prices when the store returned no products.
  final ProductDetails? details;

  /// Recurring price after any trial, e.g. "$9.99".
  final String price;
  final double rawPrice;

  /// "month" or "year".
  final String period;

  /// Whether this user would get the free trial on this plan.
  final bool hasFreeTrial;

  const SubscriptionPlan({
    required this.details,
    required this.price,
    required this.rawPrice,
    required this.period,
    required this.hasFreeTrial,
  });

  bool get isPurchasable => details != null;
}

/// Owns the App Store / Google Play subscription state.
///
/// Access is checked against the store directly: on iOS, StoreKit 2's
/// verified transactions with an expiry in the future; on Android, the
/// subscriptions Play Billing reports as owned (it only returns active ones).
/// The subscription belongs to the store account (Apple ID / Google account).
/// The result is mirrored to `users/{uid}.subscription` for the admin side.
class SubscriptionProvider extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'clearcase',
  );
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  StreamSubscription<User?>? _authSubscription;

  bool _isStoreAvailable = false;
  bool _isReady = false;
  bool _isActive = false;
  String? _activeProductId;
  DateTime? _expiresAt;
  bool _isLoadingPlans = false;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  SubscriptionPlan? _monthly;
  SubscriptionPlan? _yearly;
  String? _lastMirrored;

  SubscriptionProvider() {
    _init();
  }

  /// True once the store has been checked at least once.
  bool get isReady => _isReady;
  bool get isActive => _isActive;
  bool get hasAccess => _isActive || !SubscriptionConfig.enforcePaywall;
  bool get isStoreAvailable => _isStoreAvailable;
  bool get isLoadingPlans => _isLoadingPlans;
  bool get isPurchasing => _isPurchasing;
  bool get isRestoring => _isRestoring;
  SubscriptionPlan? get monthly => _monthly;
  SubscriptionPlan? get yearly => _yearly;

  Future<void> _init() async {
    // Listen before anything else so renewals and purchases that finished
    // while the app was closed aren't missed.
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) => debugPrint('purchaseStream error: $e'),
    );
    try {
      _isStoreAvailable = await _iap.isAvailable();
    } catch (e) {
      debugPrint('Store availability check failed: $e');
    }
    await refresh();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _lastMirrored = null;
      } else {
        _mirrorToFirestore();
      }
    });
    await loadPlans();
  }

  /// Re-reads the active subscription from the store.
  Future<void> refresh() async {
    if (_isStoreAvailable) {
      try {
        if (Platform.isIOS) {
          await _refreshFromAppStore();
        } else {
          await _refreshFromGooglePlay();
        }
      } catch (e) {
        debugPrint('Subscription refresh failed: $e');
      }
    }
    _isReady = true;
    notifyListeners();
    _mirrorToFirestore();
  }

  Future<void> _refreshFromAppStore() async {
    final DateTime now = DateTime.now();
    SK2Transaction? best;
    DateTime? bestExpiry;
    for (final SK2Transaction t in await SK2Transaction.transactions()) {
      if (!SubscriptionConfig.productIds.contains(t.productId)) continue;
      final int? millis = int.tryParse(t.expirationDate ?? '');
      if (millis == null) continue;
      final DateTime expiry = DateTime.fromMillisecondsSinceEpoch(millis);
      if (expiry.isAfter(now) && (bestExpiry == null || expiry.isAfter(bestExpiry))) {
        best = t;
        bestExpiry = expiry;
      }
    }
    _isActive = best != null;
    _activeProductId = best?.productId;
    _expiresAt = bestExpiry;
  }

  Future<void> _refreshFromGooglePlay() async {
    final addition =
        _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final QueryPurchaseDetailsResponse response =
        await addition.queryPastPurchases();
    if (response.error != null) {
      debugPrint('queryPastPurchases error: ${response.error}');
      return;
    }
    GooglePlayPurchaseDetails? active;
    for (final GooglePlayPurchaseDetails p in response.pastPurchases) {
      if (!SubscriptionConfig.productIds.contains(p.productID)) continue;
      if (p.billingClientPurchase.purchaseState != PurchaseStateWrapper.purchased) continue;
      // Play refunds purchases that aren't acknowledged within 3 days.
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      active = p;
    }
    _isActive = active != null;
    _activeProductId = active?.productID;
    _expiresAt = null; // Play Billing doesn't expose the renewal date.
  }

  Future<void> loadPlans() async {
    _isLoadingPlans = true;
    notifyListeners();
    try {
      if (!_isStoreAvailable) {
        throw 'The ${_storeName()} is not available on this device.';
      }
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(SubscriptionConfig.productIds);
      if (response.error != null) {
        debugPrint('queryProductDetails error: ${response.error}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Subscription products not found in store: ${response.notFoundIDs}');
      }
      _monthly = await _buildPlan(response.productDetails, SubscriptionConfig.monthlyProductId, 'month');
      _yearly = await _buildPlan(response.productDetails, SubscriptionConfig.yearlyProductId, 'year');
    } catch (e) {
      debugPrint('loadPlans failed: $e');
    } finally {
      // Keep the paywall complete even when the store has nothing to sell
      // yet; purchase() explains instead of the screen showing an error.
      _monthly ??= const SubscriptionPlan(
        details: null,
        price: SubscriptionConfig.fallbackMonthlyPrice,
        rawPrice: SubscriptionConfig.fallbackMonthlyRawPrice,
        period: 'month',
        hasFreeTrial: true,
      );
      _yearly ??= const SubscriptionPlan(
        details: null,
        price: SubscriptionConfig.fallbackYearlyPrice,
        rawPrice: SubscriptionConfig.fallbackYearlyRawPrice,
        period: 'year',
        hasFreeTrial: true,
      );
      _isLoadingPlans = false;
      notifyListeners();
    }
  }

  Future<SubscriptionPlan?> _buildPlan(
      List<ProductDetails> all, String productId, String period) async {
    final List<ProductDetails> matches =
        all.where((d) => d.id == productId).toList();
    if (matches.isEmpty) return null;

    if (Platform.isIOS) {
      final ProductDetails details = matches.first;
      bool eligible = false;
      try {
        eligible = await SK2Product.isIntroductoryOfferEligible(productId);
      } catch (e) {
        debugPrint('Intro offer eligibility check failed for $productId: $e');
      }
      return SubscriptionPlan(
        details: details,
        price: details.price,
        rawPrice: details.rawPrice,
        period: period,
        hasFreeTrial: eligible,
      );
    }

    // Google Play returns one entry per offer (base plan, free trial, ...),
    // and only the offers this user is eligible for. Prefer the trial.
    GooglePlayProductDetails? base;
    GooglePlayProductDetails? trial;
    for (final ProductDetails d in matches) {
      if (d is! GooglePlayProductDetails) continue;
      final offer = _offerOf(d);
      if (offer == null) continue;
      if (offer.pricingPhases.any((phase) => phase.priceAmountMicros == 0)) {
        trial ??= d;
      } else if (offer.offerId == null) {
        base ??= d;
      }
    }
    final GooglePlayProductDetails? chosen =
        trial ?? base ?? matches.whereType<GooglePlayProductDetails>().firstOrNull;
    if (chosen == null) return null;
    // The last phase is the recurring full price.
    final PricingPhaseWrapper recurring = _offerOf(chosen)!.pricingPhases.last;
    return SubscriptionPlan(
      details: chosen,
      price: recurring.formattedPrice,
      rawPrice: recurring.priceAmountMicros / 1000000.0,
      period: period,
      hasFreeTrial: trial != null,
    );
  }

  SubscriptionOfferDetailsWrapper? _offerOf(GooglePlayProductDetails d) {
    final int? index = d.subscriptionIndex;
    final offers = d.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return null;
    return offers[index];
  }

  Future<void> purchase(BuildContext context, SubscriptionPlan plan) async {
    final ProductDetails? details = plan.details;
    if (details == null) {
      showSnackBar(context, 'Subscriptions are not available yet. Please try again later.');
      loadPlans();
      return;
    }
    _isPurchasing = true;
    notifyListeners();
    try {
      // On Android the offer token (trial or base plan) comes from
      // plan.details, which is the GooglePlayProductDetails for that offer.
      final PurchaseParam param = Platform.isAndroid
          ? GooglePlayPurchaseParam(productDetails: details)
          : PurchaseParam(productDetails: details);
      final bool started = await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) _isPurchasing = false;
    } on PlatformException catch (e) {
      debugPrint('buyNonConsumable failed: $e');
      _isPurchasing = false;
      if (context.mounted) {
        showSnackBar(context, e.message ?? 'Purchase failed. Please try again.');
      }
    }
    // Otherwise the result arrives on purchaseStream.
    notifyListeners();
  }

  Future<void> restore(BuildContext context) async {
    _isRestoring = true;
    notifyListeners();
    try {
      await _iap.restorePurchases();
      await refresh();
      if (context.mounted) {
        showSnackBar(
          context,
          _isActive
              ? 'Your subscription has been restored.'
              : 'No active subscription found for this ${_storeName()} account.',
        );
      }
    } catch (e) {
      debugPrint('restorePurchases failed: $e');
      if (context.mounted) {
        showSnackBar(context, 'Could not restore purchases. Please try again.');
      }
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    bool unlocked = false;
    for (final PurchaseDetails p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _showMessage('Your payment is pending. Access unlocks once the store confirms it.');
          continue; // still waiting; keep the spinner
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (SubscriptionConfig.productIds.contains(p.productID)) unlocked = true;
          break;
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${p.error}');
          _showMessage(p.error?.message ?? 'Purchase failed. Please try again.');
          break;
        case PurchaseStatus.canceled:
          break;
      }
      // Finishes the iOS transaction / acknowledges the Play purchase.
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('completePurchase failed: $e');
        }
      }
      _isPurchasing = false;
    }
    notifyListeners();
    if (unlocked) await refresh();
  }

  /// Opens the store's page where the user can change plan or cancel.
  Future<void> openManageSubscriptions() async {
    if (Platform.isIOS) {
      try {
        await _iap
            .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>()
            .showManageSubscriptions();
        return;
      } catch (e) {
        debugPrint('showManageSubscriptions failed: $e');
      }
      await _launch('https://apps.apple.com/account/subscriptions');
      return;
    }
    final String sku = _activeProductId != null ? 'sku=$_activeProductId&' : '';
    await _launch('https://play.google.com/store/account/subscriptions?${sku}package=${SubscriptionConfig.androidPackageName}');
  }

  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open $url: $e');
    }
  }

  /// Best-effort copy of the current state onto the user doc, written only
  /// when it changes.
  Future<void> _mirrorToFirestore() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || !_isReady) return;
    final String key = '${user.uid}|$_isActive|$_activeProductId|$_expiresAt';
    if (key == _lastMirrored) return;
    _lastMirrored = key;
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'subscription': {
          'isActive': _isActive,
          'productId': _activeProductId,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'expiresAt': _expiresAt != null ? Timestamp.fromDate(_expiresAt!) : null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      _lastMirrored = null;
      debugPrint('Subscription mirror failed: $e');
    }
  }

  String _storeName() => Platform.isIOS ? 'App Store' : 'Google Play';

  void _showMessage(String text) {
    final BuildContext? context = PushNotificationService.navigatorKey.currentContext;
    if (context != null && context.mounted) showSnackBar(context, text);
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// In-app subscription setup (App Store + Google Play, no third-party service).
///
/// Prices (AUD 9.99 / month, AUD 99.99 / year) and the 1-month free trial are
/// configured in App Store Connect and Google Play Console, not here — the
/// paywall always shows the localized price the store returns.
///
/// Create two auto-renewing subscriptions with these exact product IDs in
/// *both* stores:
///   - App Store: both in one subscription group, each with a 1-month free
///     introductory offer.
///   - Google Play: one base plan each (monthly / yearly), each with a
///     1-month free-trial offer for new customers.
class SubscriptionConfig {
  static const String monthlyProductId = 'clearcase_premium_monthly';
  static const String yearlyProductId = 'clearcase_premium_yearly';
  static const Set<String> productIds = {monthlyProductId, yearlyProductId};

  /// Shown on the paywall; must match the trial set up in both stores.
  static const String freeTrialLength = '1 month';

  /// Master switch for requiring a subscription. Keep false until the App
  /// Store Paid Apps Agreement is active and the products above are approved
  /// in both stores — until then the stores return no products and nobody
  /// could subscribe. While false, debug builds can still preview the paywall
  /// from Settings → Subscription → View Plans.
  static const bool enforcePaywall = false;

  /// Shown on the paywall only when the store returns no products (e.g. the
  /// Paid Apps Agreement isn't active yet). Real purchases always use the
  /// store's localized price.
  static const String fallbackMonthlyPrice = 'AUD 9.99';
  static const double fallbackMonthlyRawPrice = 9.99;
  static const String fallbackYearlyPrice = 'AUD 99.99';
  static const double fallbackYearlyRawPrice = 99.99;

  static const String androidPackageName = 'com.clearcase.clearcase';

  static const String termsUrl =
      'https://docs.google.com/document/d/19_TmhTBYzsrhPEviQk6IMptCLSPhJfHN4ihuBcdiZJI/edit?usp=sharing';
  static const String privacyUrl =
      'https://docs.google.com/document/d/1M0pHs1VBdUwnaNqog1H_HpkRE5mqAfxcn_F3_Sd0laA/edit?usp=sharing';
}

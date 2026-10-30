import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/static/subscription_config.dart';
import '../../core/theme/app_colors.dart';
import '../../provider/subscription_provider.dart';
import '../settings/account_screen.dart';
import '../widgets/custom_primary_button.dart';

/// Shown by [MainScreen] in place of the tabs while the user has no active
/// subscription. Lists the monthly and yearly plans with their free trial,
/// plus the auto-renewal disclosure, Restore, Terms and Privacy links the
/// stores require.
class PaywallScreen extends StatefulWidget {
  static const String routeName = '/paywall';
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  // Yearly is preselected; it's the better deal.
  bool _yearlySelected = true;

  static const List<String> _features = [
    'Log custody handovers, payments, disputes and non-compliance',
    'Reminders for your court-ordered schedule',
    'Insights on compliance and payment history',
    'PDF evidence reports for your lawyer or court',
    'AI Clean Up for your written records',
  ];

  String get _storeName => Platform.isIOS ? 'App Store' : 'Google Play';

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: AppColors.surfaceColor,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceColor,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            // Back arrow only when opened from Settings (debug preview).
            automaticallyImplyLeading: Navigator.canPop(context),
            iconTheme: const IconThemeData(color: AppColors.primary),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, AccountScreen.routeName),
                icon: const Icon(Icons.person_outline, color: AppColors.primary),
                label: const Text('Account', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Try ClearCase free for 1 month',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Clear, organised records for custody and family court matters.',
                    style: TextStyle(fontSize: 15, color: AppColors.darkGreyColor),
                  ),
                  const SizedBox(height: 24),
                  ..._features.map(_buildFeature),
                  const SizedBox(height: 24),
                  _buildPlans(context, provider),
                  const SizedBox(height: 16),
                  _buildFooterLinks(context, provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildPlans(BuildContext context, SubscriptionProvider provider) {
    if (provider.isLoadingPlans) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final SubscriptionPlan? monthly = provider.monthly;
    final SubscriptionPlan? annual = provider.yearly;
    final SubscriptionPlan? selected = (_yearlySelected ? annual : monthly) ?? annual ?? monthly;
    if (selected == null) {
      return _buildMessage('Subscription plans are not available right now.');
    }
    final String? trial = selected.hasFreeTrial ? SubscriptionConfig.freeTrialLength : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (annual != null)
          _buildPlanCard(
            plan: annual,
            title: 'Yearly',
            badge: _savingsBadge(monthly, annual),
            isSelected: selected == annual,
            onTap: () => setState(() => _yearlySelected = true),
          ),
        if (annual != null && monthly != null) const SizedBox(height: 12),
        if (monthly != null)
          _buildPlanCard(
            plan: monthly,
            title: 'Monthly',
            isSelected: selected == monthly,
            onTap: () => setState(() => _yearlySelected = false),
          ),
        const SizedBox(height: 20),
        CustomPrimaryButton(
          text: trial != null ? 'Start $trial free trial' : 'Subscribe',
          isLoading: provider.isPurchasing,
          onPressed: provider.isRestoring ? null : () => provider.purchase(context, selected),
        ),
        const SizedBox(height: 12),
        Text(
          _disclosure(selected, trial),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.greyColor),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    final String? trial = plan.hasFreeTrial ? SubscriptionConfig.freeTrialLength : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTint : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.textFieldBorderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(badge,
                              style: const TextStyle(color: AppColors.whiteColor, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trial != null
                        ? '$trial free, then ${plan.price} / ${plan.period}'
                        : '${plan.price} / ${plan.period}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Save 16%" from the store prices, or null if the yearly plan isn't
  /// cheaper than twelve months.
  String? _savingsBadge(SubscriptionPlan? monthly, SubscriptionPlan annual) {
    if (monthly == null) return null;
    final double fullYear = monthly.rawPrice * 12;
    if (fullYear <= 0) return null;
    final int percent = ((1 - annual.rawPrice / fullYear) * 100).floor();
    return percent > 0 ? 'Save $percent%' : null;
  }

  String _disclosure(SubscriptionPlan plan, String? trial) {
    final String price = plan.price;
    final String period = plan.period;
    final String start = trial != null
        ? 'Free for $trial, then $price per $period. Payment is charged to your $_storeName account when the trial ends.'
        : '$price per $period, charged to your $_storeName account.';
    return '$start The subscription renews automatically unless cancelled at least '
        '24 hours before the end of the current period. Manage or cancel any time '
        'in your $_storeName account settings.';
  }

  Widget _buildMessage(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.darkGreyColor)),
    );
  }

  Widget _buildFooterLinks(BuildContext context, SubscriptionProvider provider) {
    const TextStyle linkStyle = TextStyle(color: AppColors.primary, fontSize: 13);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          child: TextButton(
            onPressed: (provider.isRestoring || provider.isPurchasing) ? null : () => provider.restore(context),
            child: provider.isRestoring
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Restore Purchases', style: linkStyle, textAlign: TextAlign.center),
          ),
        ),
        Flexible(
          child: TextButton(
            onPressed: () => _openLink(SubscriptionConfig.termsUrl),
            child: const Text('Terms of Use', style: linkStyle, textAlign: TextAlign.center),
          ),
        ),
        Flexible(
          child: TextButton(
            onPressed: () => _openLink(SubscriptionConfig.privacyUrl),
            child: const Text('Privacy Policy', style: linkStyle, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Future<void> _openLink(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppWebView);
    } catch (e) {
      debugPrint('Could not open $url: $e');
    }
  }
}

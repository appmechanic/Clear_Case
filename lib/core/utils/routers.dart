import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/views/home/case_setup_screen.dart';
import 'package:clearcase/views/home/new_breach_screen.dart';
import 'package:clearcase/views/home/new_custody_screen.dart';
import 'package:clearcase/views/home/new_dispute_screen.dart';
import 'package:clearcase/views/home/new_entry_screen.dart';
import 'package:clearcase/views/home/new_payment_screen.dart';
import 'package:clearcase/views/home/new_remainder_screen.dart';
import 'package:clearcase/views/home/rule_configuration_screen.dart';
import 'package:clearcase/views/home/scheduled_dates_screen.dart';
import 'package:clearcase/views/insights/breach_history_screen.dart';
import 'package:clearcase/views/insights/custody_compliance_screen.dart';
import 'package:clearcase/views/insights/custody_detail_screen.dart';
import 'package:clearcase/views/insights/dispute_log_details_screen.dart';
import 'package:clearcase/views/insights/dispute_log_screen.dart';
import 'package:clearcase/views/insights/payment_analytics_screen.dart';
import 'package:clearcase/views/insights/payment_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:clearcase/views/auth/email_verification_screen.dart';
import '../../views/auth/forget_password_screen.dart';
import '../../views/auth/login_screen.dart';
import '../../views/auth/signup_screen.dart';
import '../../views/auth/splash_screen.dart';
import '../../views/main_screen.dart';

Map<String, Widget Function(BuildContext)> getAppRoutes() {
  Map<String, Widget Function(BuildContext)> appRoutes = {
    SplashScreen.routeName: (context) => const SplashScreen(),
    LoginScreen.routeName: (context) => LoginScreen(),
    SignupScreen.routeName: (context) => SignupScreen(),
    ForgotPasswordScreen.routeName: (context) => const ForgotPasswordScreen(),
    EmailVerificationScreen.routeName: (context) => EmailVerificationScreen(),
    MainScreen.routeName: (context) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      final int index = (arguments is int) ? arguments : 0;
      return MainScreen(index: index);
    },
    CaseSetupScreen.routeName: (context) => const CaseSetupScreen(),
    NewEntryScreen.routeName: (context) => const NewEntryScreen(),
    NewCustodyScreen.routeName: (context) => const NewCustodyScreen(),
    NewPaymentScreen.routeName: (context) => const NewPaymentScreen(),
    NewDisputeScreen.routeName: (context) => const NewDisputeScreen(),
    NewBreachScreen.routeName: (context) => const NewBreachScreen(),
    ScheduledDatesScreen.routeName: (context) => const ScheduledDatesScreen(),
    RuleConfigurationScreen.routeName: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return RuleConfigurationScreen(

        caseId: args?['caseId'],
        category: args?['category'] ?? 'custody',
        availableChildren: (args?['availableChildren'] as List<dynamic>?)?.cast<ChildModel>() ?? [],
      );
    },
    NewReminderScreen.routeName: (context) => const NewReminderScreen(),
    CustodyComplianceScreen.routeName: (context) => const CustodyComplianceScreen(),
    PaymentAnalyticsScreen.routeName: (context) => const PaymentAnalyticsScreen(),
    DisputesLogScreen.routeName: (context) => const DisputesLogScreen(),
    BreachHistoryScreen.routeName: (context) => const BreachHistoryScreen(),
    PaymentDetailsScreen.routeName: (context) => const PaymentDetailsScreen(),
    CustodyDetailsScreen.routeName: (context) => const CustodyDetailsScreen(),
    DisputeDetailsScreen.routeName: (context) => const DisputeDetailsScreen(),
  };
  return appRoutes;
}

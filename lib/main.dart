import 'package:clearcase/provider/auth_provider.dart';
import 'package:clearcase/provider/breach_provider.dart';
import 'package:clearcase/provider/breach_provider_insight.dart';
import 'package:clearcase/provider/calender_provider.dart';
import 'package:clearcase/provider/case_setup_provider.dart';
import 'package:clearcase/provider/custody_insight_provider.dart';
import 'package:clearcase/provider/dispute_insight_provider.dart';
import 'package:clearcase/provider/dispute_provider.dart';
import 'package:clearcase/provider/insight_provider.dart';
import 'package:clearcase/provider/main_provider.dart';
import 'package:clearcase/provider/new_entry_provider.dart';
import 'package:clearcase/provider/payment_provider_insight.dart';
import 'package:clearcase/provider/remainder_provider.dart';
import 'package:clearcase/provider/rule_configuration_provider.dart';
import 'package:clearcase/provider/scheduled_dates_provider.dart';
import 'package:clearcase/provider/setting_provider.dart';
import 'package:clearcase/views/auth/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/utils/routers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => CaseSetupProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => NewEntryProvider()),
        ChangeNotifierProvider(create: (_) => ScheduledDatesProvider()),
        ChangeNotifierProvider(create: (_) => RuleConfigurationProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => DisputeProvider()),
        ChangeNotifierProvider(create: (_) => BreachProvider()),
        ChangeNotifierProvider(create: (_) => InsightProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => BreachProviderInsight()),
        ChangeNotifierProvider(create: (_) => DisputeInsightsProvider()),
        ChangeNotifierProvider(create: (_) => CustodyInsightProvider()),
      ],
      child: MaterialApp(
      title: 'ClearCase',
      debugShowCheckedModeBanner: false,
      routes: getAppRoutes(),
      theme: ThemeData(
        fontFamily: 'Jost',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: SplashScreen.routeName,
    ));
  }
}

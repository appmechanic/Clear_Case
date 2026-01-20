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
    }
  };
  return appRoutes;
}

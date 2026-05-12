import 'package:clearcase/views/auth/signup_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helping_functions.dart';
import '../../provider/auth_provider.dart';
import '../widgets/custom_primary_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_auth_button.dart';
import 'auth_controller.dart';
import 'forget_password_screen.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authController = AuthController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.surfaceColor,
        body: Consumer<AuthProvider>(
          builder: (context, provider, child) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(height: getDeviceHeight(context) * 0.05),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome',
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      CustomTextField(
                          labelText: "Email",
                          controller: authController.emailController,
                          node: authController.emailFocusNode,
                          hintText: "Enter your email",
                          isCap: false,
                          nextNode: authController.passwordFocusNode
                      ),
                      SizedBox(height: 16),
                      CustomTextField(
                          labelText: "Password",
                          controller: authController.passwordController,
                          isPassword: true,
                          node: authController.passwordFocusNode,
                          hintText: "Enter your password",
                          nextNode: null
                      ),
                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, ForgotPasswordScreen.routeName);
                            authController.clearControllers();
                          },
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      CustomPrimaryButton(
                        text: 'Login',
                        isLoading: provider.isLoading,
                        onPressed: provider.isGoogleLoading
                            ? null
                            : () {
                                if (authController.isLoginValidate(context: context)) {
                                  provider.loginFunction(
                                    context: context,
                                    email: authController.emailController.text.trim(),
                                    password: authController.passwordController.text.trim(),
                                  );
                                }
                              },
                      ),

                      const SizedBox(height: 32),

                      const OrContinueWithDivider(),
                      const SizedBox(height: 20),
                      SocialAuthButton(
                        isLoading: provider.isGoogleLoading,
                        onPressed: provider.isLoading
                            ? null
                            : () => provider.googleSignInFunction(context: context),
                      ),

                      const SizedBox(height: 32),

                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.greyColor,
                            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                          ),
                          children: [
                            TextSpan(text: 'Do not have an account? '),
                            TextSpan(
                              text: 'Create Account',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  authController.clearControllers();
                                  Navigator.pushNamed(context, SignupScreen.routeName);
                                },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24)
                    ],
                  ),
                ),
              ),
            );
          },
        )
    );
  }
}


import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helping_functions.dart';
import '../../provider/auth_provider.dart';
import '../widgets/custom_primary_button.dart';
import '../widgets/custom_text_field.dart';
import 'auth_controller.dart';

class SignupScreen extends StatefulWidget {
  static const routeName = '/signup';
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final authController = AuthController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // context.read<AuthProvider>().resetSignUpState();
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.surfaceColor,
        body: Consumer<AuthProvider>(
          builder: (context, provider, child) {
            return  SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: getDeviceHeight(context) * 0.05),
                        Text(
                          'Create an Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 48),
                          CustomTextField(
                            labelText: "First Name",
                            controller: authController.fullNameController,
                            node: authController.fullNameFocusNode,
                            hintText: "Enter your first name",
                            nextNode: authController.emailFocusNode,
                            // isReadOnly: provider.isOtpSent,
                          ),
                        SizedBox(height: 16),
                        CustomTextField(
                          labelText: "Last Name",
                          controller: authController.otpController,
                          node: authController.otpFocusNode,
                          hintText: "Enter your last name",
                          nextNode: null,
                        ),
                        SizedBox(height: 16),
                          CustomTextField(
                            labelText: "Email",
                            controller: authController.emailController,
                            node: authController.emailFocusNode,
                            hintText: "Enter your email",
                            isCap: false,
                            // nextNode: provider.isOtpSent ? authController.otpFocusNode : null,
                            // isReadOnly: provider.isOtpSent,
                          ),
                        SizedBox(height: 16),
                        CustomTextField(
                            labelText: "Password",
                            controller: authController.passwordController,
                            isPassword: true,
                            node: authController.passwordFocusNode,
                            hintText: "Enter your password",
                            nextNode: null,
                          ),
                        SizedBox(height: 16),
                        // if (provider.isOtpSent && !provider.isEmailVerified)...[

                        // ],
                          
                        const SizedBox(height: 24),
                        // if (provider.isEmailVerified)
                          CustomPrimaryButton(
                              text: "Create Account",
                              isLoading: provider.isLoading,
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  String fullName = "${authController.fullNameController.text.trim()} ${authController.otpController.text.trim()}";

                                  provider.signUpFunction(
                                    context: context,
                                    email: authController.emailController.text.trim(),
                                    password: authController.passwordController.text.trim(),
                                    fullName: fullName,
                                  );
                                }
                              }),
                         const SizedBox(height: 34),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.greyColor,
                                  fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                                ),
                                children: [
                                  TextSpan(text: 'Already have an account? '),
                                  TextSpan(
                                    text: 'Login',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.pop(context);
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24)
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        )
    );
  }
}

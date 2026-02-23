import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helping_functions.dart';
import '../../provider/auth_provider.dart';
import '../widgets/custom_primary_button.dart';
import '../widgets/custom_text_field.dart';
import 'auth_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const routeName = '/forgetPassword';
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authController = AuthController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.surfaceColor,
        body: Consumer<AuthProvider>(
          builder: (context, provider, child) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 18, right: 18),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: getDeviceHeight(context) * 0.06),
                        Text(
                          'Forgot Password ?',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            "Please enter your registered email to receive password reset instructions ",
                            textAlign: TextAlign.left,
                            style: TextStyle(
                                color: AppColors.darkGreyColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: getDeviceHeight(context) * 0.04),
                        CustomTextField(
                            labelText: "Email",
                            controller: _authController.emailController,
                            node: _authController.emailFocusNode,
                            hintText: "Enter your email",
                            nextNode: _authController.passwordFocusNode
                        ),
                        SizedBox(height: getDeviceHeight(context) * 0.08),
                        CustomPrimaryButton(
                          text: 'Send Reset Link',
                          isLoading: provider.isLoading, // Show loading spinner
                          onPressed: () {
                            provider.forgetPasswordFunction(
                              context: context,
                              email: _authController.emailController.text.trim(),
                            );
                            _authController.clearControllers();
                          },
                        ),
                        SizedBox(height: getDeviceHeight(context) * 0.04),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(onPressed: (){
                              Navigator.pop(context);
                            }, child: Text("Back to Login", style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w600))),
                          ],
                        ),
                        SizedBox(height: getDeviceHeight(context) * 0.06),
                        Text(
                            "Check your spam folder in case you did not find the mail.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.darkGreyColor, fontSize: 14)),
                        SizedBox(height: getDeviceHeight(context) * 0.02),
                      ]
                  ),
                ),
              ),
            );
          },
        )
    );
  }
}

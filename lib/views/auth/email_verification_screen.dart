import 'package:clearcase/views/widgets/custom_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../provider/auth_provider.dart';
import '../widgets/custom_secondary_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  static const routeName = '/email-verification';
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 50),
                        const Text(
                          "Email Verification Sent",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          textAlign: TextAlign.start,
                          maxLines: 4,
                          "We've sent a confirmation link to your email. Please verify to continue.",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.greyColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 60),
                        CustomPrimaryButton(
                          text: "Resend Email",
                          isLoading: provider.isLoading,
                          onPressed: () async {
                            await provider.resendVerificationEmail(context);
                          },
                        ),
                        const SizedBox(height: 20),
                        CustomSecondaryButton(
                          text: "Back to Login",
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),

                  )
              ),
            );
          },
        )
    );
  }
}

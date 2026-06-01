import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.whiteColor,
          disabledBackgroundColor: AppColors.whiteColor,
          foregroundColor: Colors.black87,
          shadowColor: Colors.transparent,
          elevation: 0,
          side: BorderSide(
            color: AppColors.greyColor.withValues(alpha: 0.4),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/google.svg',
                    height: 22,
                    width: 22,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue With Google',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const AppleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    if (!Platform.isIOS) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff1E1E2A),
          disabledBackgroundColor: const Color(0xff1E1E2A),
          foregroundColor: AppColors.whiteColor,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.whiteColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/apple.svg',
                    height: 22,
                    width: 22,
                    colorFilter: const ColorFilter.mode(
                      AppColors.whiteColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue With Apple',
                    style: TextStyle(
                      color: AppColors.whiteColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class OrContinueWithDivider extends StatelessWidget {
  const OrContinueWithDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.greyColor.withValues(alpha: 0.4), thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: TextStyle(
              color: AppColors.greyColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: AppColors.greyColor.withValues(alpha: 0.4), thickness: 1),
        ),
      ],
    );
  }
}

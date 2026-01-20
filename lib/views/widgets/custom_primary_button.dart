import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CustomPrimaryButton extends StatelessWidget {
  final IconData? prefixIcon;
  final bool isOutlined;
  final Color textColor;
  final Color borderColor;
  final String text;
  final VoidCallback? onPressed;
  final double? fontSize;
  final Widget? child;
  final bool isLoading;
  final Color? backgroundColor;

  const CustomPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isOutlined = false,
    this.backgroundColor = AppColors.primary,
    this.borderColor = Colors.transparent,
    this.textColor = AppColors.whiteColor,
    this.fontSize,
    this.prefixIcon,
    this.child,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(25);

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        disabledBackgroundColor: AppColors.primary,
        shadowColor: Colors.transparent,
        elevation: 3,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      child: _buildButtonContent(),
    );
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (prefixIcon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              prefixIcon,
              size: 18,
              color: textColor,
            ),
          ),
        Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize?? 16,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
      );
  }
}

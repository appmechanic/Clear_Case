import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CustomSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color textColor;
  final Color borderColor;
  final bool isLoading;
  final double? fontSize;
  final Widget? prefixWidget;

  const CustomSecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.textColor = AppColors.primary,
    this.borderColor = AppColors.primary,
    this.isLoading = false,
    this.fontSize,
    this.prefixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.backgroundCards,
        foregroundColor: AppColors.primary,
        shadowColor: AppColors.backgroundCards.withValues(alpha: 0.6),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 3,
      ),
      child: _buildButtonContent(),
    );
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
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
        if (prefixWidget != null) ...[
          prefixWidget!,
          const SizedBox(width: 12),
        ],
        Text(
          text,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
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
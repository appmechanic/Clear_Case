import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const AppLoader({
    super.key,
    this.size = 40.0,
    this.strokeWidth = 4.0,
    Color? color,
  })  : color = color ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: size / 15,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}


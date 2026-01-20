
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color titleColor;
  const CustomAppBar({super.key, required this.title, this.titleColor = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: AppColors.greyColor, size: 28),
              onPressed: () {
                
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80.0);
}
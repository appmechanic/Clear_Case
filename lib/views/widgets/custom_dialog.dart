import 'package:flutter/material.dart';

class TopPopupDialog {
  static void show({
    required BuildContext context,
    required Widget child,
    double topMargin = 10,
    double horizontalMargin = 20,
  }) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Popup",
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      pageBuilder: (_, _, _) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: EdgeInsets.only(top: topMargin, left: horizontalMargin, right: horizontalMargin),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: child,
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, _, child) {
        return SlideTransition(
          position: Tween(begin: Offset(0, -1), end: Offset(0, 0)).animate(anim),
          child: child,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:new_renitek/const/custom_textstyle.dart';

class SnackbarHelper {
  static void showSuccess(
    BuildContext context,
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(context,
        isSuccess: true, title: title, message: message, duration: duration);
  }

  static void showError(
    BuildContext context,
    String title,
    String message, {
    Duration duration = const Duration(seconds: 5),
  }) {
    _show(context,
        isSuccess: false, title: title, message: message, duration: duration);
  }

  static void showInfo(
    BuildContext context,
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(context,
        isSuccess: null, title: title, message: message, duration: duration);
  }

  static void _show(
    BuildContext context, {
    required bool? isSuccess,
    required String title,
    required String message,
    required Duration duration,
  }) {
    IconData icon;
    Color backgroundColor;

    if (isSuccess == true) {
      icon = Icons.check_circle_rounded;
      backgroundColor = Colors.green.shade600;
    } else if (isSuccess == false) {
      icon = Icons.error_rounded;
      backgroundColor = Colors.red.shade600;
    } else {
      icon = Icons.info_outline_rounded;
      backgroundColor = Colors.blue.shade600;
    }

    final overlayState = Overlay.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    late OverlayEntry messageOverlay;

    messageOverlay = OverlayEntry(builder: (context) {
      return Positioned(
        top: topPadding + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: CustomTextStyle.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: CustomTextStyle.bodyMedium
                          .copyWith(color: Colors.white),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      );
    });

    overlayState.insert(messageOverlay);

    Future.delayed(duration).then((_) {
      if (messageOverlay.mounted) {
        messageOverlay.remove();
      }
    });
  }
}

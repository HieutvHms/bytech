import 'package:flutter/material.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';

void showStatus(
    {required BuildContext buildContext,
    required bool succcess,
    required String message}) async {
  final overlayContext = buildContext;
  OverlayState? overlayState = Overlay.of(overlayContext);
  OverlayEntry messageOverlay;
  final size = MediaQuery.of(overlayContext).size;

  messageOverlay = OverlayEntry(builder: (context) {
    return Positioned(
      top: 48,
      left: size.width * 0.05,
      right: size.width * 0.05,
      child: Container(
        height: 50,
        width: size.width * 0.9,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: succcess
            ? _message(message, CustomColor.stateGreen, Icons.check)
            : _message(message, CustomColor.stateRed, Icons.error),
      ),
    );
  });
  overlayState.insert(messageOverlay);

  // Awaiting for 3 seconds to close this over lay
  await Future.delayed(const Duration(seconds: 3));
  messageOverlay.remove();
}

Widget _message(String message, Color color, IconData icon) {
  return Scaffold(
    backgroundColor: color,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                message,
                style: CustomTextStyle.bodyMedium
                    .copyWith(color: CustomColor.neutralWhite),
              ),
            ),
            Icon(
              icon,
              size: 15,
              color: CustomColor.neutralWhite,
            ),
          ],
        ),
      ),
    ),
  );
}

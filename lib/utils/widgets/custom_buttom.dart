import 'package:flutter/material.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.title,
    required this.onTap,
    required this.enable,
    this.isLoading,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.height,
  });
  final String title;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final bool enable;
  final bool? isLoading;
  final double? height;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (enable) {
          onTap();
        }
      },
      onLongPressStart: (s) {
        if (enable) {
          onLongPressStart!();
        }
      },
      onLongPressEnd: (s) {
        if (enable) {
          onLongPressEnd!();
        }
      },
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: enable ? CustomColor.pastel5 : CustomColor.neutralBlack50,
        ),
        child: isLoading == true
            ? const CircularProgressIndicator(
                strokeWidth: 2,
                color: CustomColor.neutralWhite,
              )
            : Text(
                title,
                style: CustomTextStyle.bodyMedium,
              ),
      ),
    );
  }
}

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
  });
  final String title;
  final VoidCallback onTap;
  final bool enable;
  final bool? isLoading;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (enable) {
          onTap();
        }
      },
      child: Container(
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

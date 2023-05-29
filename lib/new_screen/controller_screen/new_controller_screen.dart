import 'package:flutter/material.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';
import 'package:reintechnik/new_screen/home/home_screen.dart';

class NewControllerScreen extends StatelessWidget {
  const NewControllerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Row(
            children: const [],
          ),
          const SizedBox(height: 48),
          const ConnectDeviceWidget(
            deviceName: 'Name',
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
          ),
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Text('Press and hold button to control device'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ControlerButton(
                      onTap: () {},
                      iconData: Icons.arrow_back,
                      title: 'Move in',
                    ),
                    ControlerButton(
                      onTap: () {},
                      iconData: Icons.arrow_forward,
                      title: 'Move out',
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ControlerButton extends StatelessWidget {
  const ControlerButton(
      {super.key,
      required this.title,
      required this.onTap,
      required this.iconData});
  final String title;
  final VoidCallback onTap;
  final IconData iconData;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // borderRadius: BorderRadius.circular(60),
            border: Border.all(
              color: CustomColor.primaryColor,
              width: 4,
            ),
          ),
          child: Icon(
            iconData,
            color: CustomColor.primaryColor,
            size: 30,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: CustomTextStyle.bodyMedium,
        )
      ],
    );
  }
}

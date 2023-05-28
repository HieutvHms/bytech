import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';
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
            children: [],
          ),
          SizedBox(height: 48),
          ConnectDeviceWidget(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
          ),
          Container(
            alignment: Alignment.center,
            margin: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text('Press and hold button to control device'),
                SizedBox(height: 16),
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
          padding: EdgeInsets.all(12),
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
        SizedBox(height: 4),
        Text(
          title,
          style: CustomTextStyle.bodyMedium,
        )
      ],
    );
  }
}

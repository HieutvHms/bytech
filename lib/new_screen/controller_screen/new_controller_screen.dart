import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/const/asset_const.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';
import 'package:reintechnik/new_screen/home/home_screen.dart';
import 'package:reintechnik/providers/app_provider.dart';

class DeviceParam {
  final String deviceName;
  final ConnectStatus connectStatus;

  DeviceParam({
    required this.deviceName,
    required this.connectStatus,
  });
}

class NewControllerScreen extends StatelessWidget {
  const NewControllerScreen({super.key, required this.deviceParam});
  final DeviceParam deviceParam;
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Scaffold(
      backgroundColor: CustomColor.neutralWhite90,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: CustomColor.neutralWhite90,
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: const ImageIcon(
            AssetImage(AssetConst.backArrow),
            color: CustomColor.neutralBlack,
          ),
        ),
        title: Text(
          deviceParam.deviceName,
          style: CustomTextStyle.h4Medium,
        ),
        actions: const [
          ImageIcon(
            AssetImage(AssetConst.moreMenu),
            color: CustomColor.neutralBlack,
          ),
          SizedBox(width: 16)
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          ConnectDeviceWidget(
            deviceName: deviceParam.deviceName,
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Image.asset(AssetConst.screenImage),
          ),
          StreamBuilder(
            stream: Provider.of<AppProvider>(context).motorStatus,
            builder: (ctx, snapshot) => Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
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
                        enable: snapshot.data?.canMoveIn() == true,
                        onLongPressStart: () {
                          provider.controlMotor(ControlType.GO_IN);
                        },
                        onLongPressEnd: () {
                          provider.controlMotor(ControlType.STOP);
                        },
                      ),
                      ControlerButton(
                        onTap: () {},
                        iconData: Icons.arrow_forward,
                        title: 'Move out',
                        enable: snapshot.data?.canMoveOut() == true,
                        onLongPressStart: () {
                          provider.controlMotor(ControlType.GO_OUT);
                        },
                        onLongPressEnd: () {
                          provider.controlMotor(ControlType.STOP);
                        },
                      ),
                    ],
                  )
                ],
              ),
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
      required this.iconData,
      this.onLongPressStart,
      this.onLongPressEnd,
      required this.enable});
  final String title;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final IconData iconData;
  final bool enable;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (enable) {
          onTap();
        }
      },
      onLongPressDown: (s) {
        if (enable && onLongPressStart != null) {
          onLongPressStart!();
        }
      },
      onLongPressUp: () {
        if (enable && onLongPressEnd != null) {
          onLongPressEnd!();
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // borderRadius: BorderRadius.circular(60),
              border: Border.all(
                color: enable
                    ? CustomColor.primaryColor
                    : CustomColor.neutralBlack50,
                width: 4,
              ),
            ),
            child: Icon(
              iconData,
              color: enable
                  ? CustomColor.primaryColor
                  : CustomColor.neutralBlack50,
              size: 30,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: CustomTextStyle.bodyMedium,
          )
        ],
      ),
    );
  }
}

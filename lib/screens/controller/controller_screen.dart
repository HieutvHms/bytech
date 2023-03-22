import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';
import 'package:reintechnik/providers/app_provider.dart';
import 'package:reintechnik/utils/widgets/custom_buttom.dart';

class ControllerScreen extends StatelessWidget {
  const ControllerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    return Scaffold(
      body: (provider.socketTCP != null || provider.bluetoothDevice != null)
          ? const ControllerBoard()
          : const Center(
              child: Text(
                "Chưa có thiết bị kết nối để điều khiển vui lòng kết nối và thử lại!!!",
                maxLines: 3,
                style: CustomTextStyle.h3Medium,
              ),
            ),
    );
  }
}

class ControllerBoard extends StatelessWidget {
  const ControllerBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    return StreamBuilder(
      stream: provider.motorStatus,
      builder: (context, snapshot) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: const Color.fromARGB(255, 223, 212, 249),
              elevation: 10,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: const [
                        Flexible(
                          flex: 4,
                          child: Text(
                            'Device is available.Now you can control it',
                            style: CustomTextStyle.h4Medium,
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: Icon(
                            Icons.bluetooth,
                            color: CustomColor.neutralBlack20,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Hành trình của MOTOR:',
                      style: CustomTextStyle.h4Medium,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 50,
                      width: MediaQuery.of(context).size.width - 80,
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 500),
                            left: (((snapshot.data?.position ?? 0) / 100) *
                                (MediaQuery.of(context).size.width - 120)),
                            child: Container(
                              height: 20,
                              width: 20,
                              decoration: BoxDecoration(
                                  color: CustomColor.stateGreen,
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomButton(
                          title: 'MOVE IN ',
                          onLongPressStart: () {
                            provider.controlMotor(ControlType.GO_IN);
                          },
                          onLongPressEnd: () {
                            provider.controlMotor(ControlType.STOP);
                          },
                          onTap: () {},
                          enable: snapshot.data?.canMoveIn() == true,
                        ),
                        CustomButton(
                          title: 'MOVE OUT',
                          onTap: () {},
                          onLongPressStart: () {
                            provider.controlMotor(ControlType.GO_OUT);
                          },
                          onLongPressEnd: () {
                            provider.controlMotor(ControlType.STOP);
                          },
                          enable: snapshot.data?.canMoveOut() == true,
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

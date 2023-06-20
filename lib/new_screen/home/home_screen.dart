import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/const/asset_const.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';
import 'package:reintechnik/new_screen/personal/profile_screen.dart';
import 'package:reintechnik/providers/app_provider.dart';

class NewHomeScreen2 extends StatelessWidget {
  const NewHomeScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Scaffold(
      // key: globalKey,
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipPath(
                  clipper: WaveClipper(),
                  child: Container(
                    width: double.maxFinite,
                    // color: Colors.amberAccent,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF42ABE8),
                          Color(0xFF0A6294),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset(AssetConst.logo),
                              const SizedBox(height: 16),
                              Text(
                                'Welcome,',
                                style: CustomTextStyle.bodyLight
                                    .copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Mr.David',
                                style: CustomTextStyle.h4Medium
                                    .copyWith(color: Colors.white),
                              ),
                            ]),
                        // Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (ctx) => const ProfileScreen()));
                          },
                          child: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: CustomColor.neutralWhite,
                    ),
                    child: Consumer<AppProvider>(
                      builder: (context, value, child) {
                        if (value.bluetoothDevice != null &&
                            provider.connectStatus == ConnectStatus.BLE) {
                          return Row(
                            children: [
                              _info(value.bleDeviceList.length.toString(),
                                  "Devices"),
                              const SizedBox(
                                width: 30,
                              ),
                              _info("1", "Connected"),
                              const SizedBox(
                                width: 30,
                              ),
                              _info(
                                (value.bleDeviceList.length - 1).toString(),
                                "Disconnected",
                              ),
                            ],
                          );
                        } else if (value.mdnsConnectedClient != null &&
                            provider.connectStatus == ConnectStatus.SOCKET) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _info(value.localService.length.toString(),
                                  "Devices"),
                              const SizedBox(
                                width: 30,
                              ),
                              _info("1", "Connected"),
                              const SizedBox(
                                width: 30,
                              ),
                              _info(
                                (value.localService.length - 1).toString(),
                                "Disconnected",
                              ),
                            ],
                          );
                        } else {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No information',
                              style: CustomTextStyle.h3Medium,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  "All devices",
                  style: CustomTextStyle.h5Medium.copyWith(
                    color: CustomColor.neutralBlack50,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<AppProvider>(
              builder: (context, value, child) {
                if (value.connectStatus == ConnectStatus.BLE) {
                  return ListView.builder(
                    itemCount: value.bleDeviceList.length,
                    itemBuilder: (ctx, index) => _deviceCard(
                      value.bleDeviceList[index].name,
                      ConnectStatus.BLE,
                      context,
                    ),
                  );
                } else if (value.connectStatus == ConnectStatus.SOCKET) {
                  return ListView.builder(
                    itemCount: value.localService.length,
                    itemBuilder: (ctx, index) => _deviceCard(
                      value.localService[index].name ?? "",
                      ConnectStatus.SOCKET,
                      context,
                    ),
                  );
                } else {
                  return const SizedBox();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String title, String info) {
    return Column(
      children: [
        Text(
          title,
          style: CustomTextStyle.h3Medium,
        ),
        Text(
          info,
          style: CustomTextStyle.bodyLight,
        ),
      ],
    );
  }
}

Widget _deviceCard(
    String deviceName, ConnectStatus connectStatus, BuildContext context) {
  final provider = Provider.of<AppProvider>(context);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CustomColor.neutralWhite,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const CircleAvatar(
              child: ImageIcon(AssetImage(AssetConst.deviceIcon)),
            ),
            ImageIcon(AssetImage(connectStatus == ConnectStatus.BLE
                ? AssetConst.bluetoothIcon
                : AssetConst.wifiIcon))
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                deviceName,
                style: CustomTextStyle.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 24),
            if (deviceName == provider.bluetoothDevice?.name ||
                deviceName == provider.mdnsConnectedClient?.name)
              StreamBuilder(
                stream: Provider.of<AppProvider>(context).motorStatus,
                builder: (context, snapshot) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      HomeControlButton(
                        onTap: () {},
                        iconData: Icons.arrow_back,
                        enable: snapshot.data?.canMoveIn() == true,
                        onLongPressStart: () {
                          provider.controlMotor(ControlType.GO_IN);
                        },
                        onLongPressEnd: () {
                          provider.controlMotor(ControlType.STOP);
                        },
                      ),
                      const SizedBox(width: 12),
                      HomeControlButton(
                        onTap: () {},
                        iconData: Icons.arrow_forward,
                        enable: snapshot.data?.canMoveOut() == true,
                        onLongPressStart: () {
                          provider.controlMotor(ControlType.GO_OUT);
                        },
                        onLongPressEnd: () {
                          provider.controlMotor(ControlType.STOP);
                        },
                      ),
                    ],
                  );
                },
              )
          ],
        )
      ],
    ),
  );
}

class HomeControlButton extends StatelessWidget {
  const HomeControlButton(
      {super.key,
      required this.onTap,
      this.onLongPressStart,
      this.onLongPressEnd,
      required this.iconData,
      required this.enable});
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
      onLongPressEnd: (e) {
        if (enable && onLongPressEnd != null) {
          onLongPressEnd!();
        }
      },
      onLongPressCancel: () {
        if (enable && onLongPressEnd != null) {
          onLongPressEnd!();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enable ? CustomColor.primaryColor : CustomColor.neutralBlack50,
          // borderRadius: BorderRadius.circular(60),
        ),
        child: Icon(
          iconData,
          color: CustomColor.neutralWhite,
          size: 24,
        ),
      ),
    );
  }
}

class DeviceConnectCard extends StatelessWidget {
  const DeviceConnectCard(
      {super.key, required this.devicename, required this.connect});
  final String devicename;
  final VoidCallback connect;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              devicename,
              style: CustomTextStyle.bodyLight,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          CustomOutLineButton(title: 'Connect', ontap: connect),
        ],
      ),
    );
  }
}

class CustomOutLineButton extends StatelessWidget {
  const CustomOutLineButton(
      {super.key, required this.title, required this.ontap, this.color});
  final String title;
  final VoidCallback ontap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color ?? CustomColor.primaryColor,
          ),
        ),
        child: Text(
          title,
          style: CustomTextStyle.bodyMedium.copyWith(
            color: color ?? CustomColor.primaryColor,
          ),
        ),
      ),
    );
  }
}

class BluetoothWarning extends StatelessWidget {
  const BluetoothWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundImage: const AssetImage(AssetConst.noBluetooth),
            backgroundColor: CustomColor.stateRed.withOpacity(0.5),
          ),
          const Text(
            "Bluetooth has been turned off.\nPlease turn it on to start scanning.",
            textAlign: TextAlign.center,
            style: CustomTextStyle.bodyLight,
          )
        ],
      ),
    );
  }
}

class WifiWarning extends StatelessWidget {
  const WifiWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundImage: const AssetImage(AssetConst.noWifiIcon),
            backgroundColor: CustomColor.stateRed.withOpacity(0.5),
          ),
          const Text(
            "WIFI has been turned off.\nPlease turn it on to start scanning.",
            textAlign: TextAlign.center,
            style: CustomTextStyle.bodyLight,
          )
        ],
      ),
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(
      0,
      size.height / 2,
    );
    path.quadraticBezierTo(
        size.width * 0.55, size.height, size.width, size.height * 0.7);

    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}

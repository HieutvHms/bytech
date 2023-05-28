import 'package:flutter/material.dart';
import 'package:reintechnik/const/asset_const.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';

class NewHomeScreen2 extends StatelessWidget {
  const NewHomeScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.35,
                  width: double.maxFinite,
                  // color: Colors.amberAccent,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0xFF42ABE8),
                      Color(0xFF0A6294),
                    ]),
                  ),
                ),
                Positioned(
                  top: 60,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 32),
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset(AssetConst.logo),
                              SizedBox(height: 16),
                              Text(
                                'Welcome,',
                                style: CustomTextStyle.bodyLight
                                    .copyWith(color: Colors.white),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Mr.David',
                                style: CustomTextStyle.h4Medium
                                    .copyWith(color: Colors.white),
                              ),
                            ]),
                        // Spacer(),
                        CircleAvatar(
                          child: Icon(Icons.person),
                          backgroundColor: Colors.white,
                        )
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 10,
                  child: ConnectDeviceWidget(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              expandedCrossAxisAlignment: CrossAxisAlignment.center,
              title: Row(
                children: const [
                  CircleAvatar(
                    backgroundImage: AssetImage(AssetConst.bluetoothIcon),
                    radius: 12,
                    backgroundColor: CustomColor.neutralWhite96,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Bluetooth connections',
                    style: CustomTextStyle.h5Medium,
                  ),
                ],
              ),
              children: [
                BluetoothWarning(),
                // SizedBox(
                //   height: MediaQuery.of(context).size.height * 0.5,
                //   child: ListView.separated(
                //     itemBuilder: (ctx, index) => DeviceConnectCard(
                //       connect: () {},
                //       devicename: 'APLS-0001',
                //     ),
                //     itemCount: 10,
                //     separatorBuilder: (context, index) => const Divider(),
                //   ),
                // ),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: Row(
                children: const [
                  CircleAvatar(
                    backgroundImage: AssetImage(AssetConst.wifiIcon),
                    radius: 12,
                    backgroundColor: CustomColor.neutralWhite96,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Wifi connections',
                    style: CustomTextStyle.h5Medium,
                  ),
                ],
              ),
              children: [
                WifiWarning()
                // SizedBox(
                //   height: MediaQuery.of(context).size.height * 0.5,
                //   child: ListView.separated(
                //     itemBuilder: (ctx, index) => DeviceConnectCard(
                //       connect: () {},
                //       devicename: 'APLS-0001',
                //     ),
                //     itemCount: 10,
                //     separatorBuilder: (context, index) => const Divider(),
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectDeviceWidget extends StatelessWidget {
  const ConnectDeviceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      width: MediaQuery.of(context).size.width * 0.9,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'ON CONNECTED',
                style: CustomTextStyle.bodyMedium,
              ),
              ImageIcon(
                AssetImage(AssetConst.bluetoothIcon),
                size: 24,
                color: CustomColor.primaryColor,
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ALPS-0001',
                style: CustomTextStyle.h4Medium,
              ),
            ],
          )
        ],
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
          Text(
            devicename,
            style: CustomTextStyle.bodyLight,
          ),
          CustomOutLineButton(title: 'Connect', ontap: () {}),
        ],
      ),
    );
  }
}

class CustomOutLineButton extends StatelessWidget {
  const CustomOutLineButton(
      {super.key, required this.title, required this.ontap});
  final String title;
  final VoidCallback ontap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CustomColor.primaryColor,
          ),
        ),
        child: Text(
          title,
          style: CustomTextStyle.bodyMedium.copyWith(
            color: CustomColor.primaryColor,
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
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundImage: AssetImage(AssetConst.noBluetooth),
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
// class WaveClipper extends CustomClipper<Path> {
//   @override
//   Path getClip(Size size) {
//     var path = Path();
//     path.lineTo(
//       0,
//       size.height - 100,
//     );
//     final firstStart = Offset(size.width / 0.5, size.height - 100);
//     final firstEnd = Offset(size.width / 0.75, size.height);
//     path.quadraticBezierTo(
//         firstStart.dx, firstStart.dy, firstEnd.dx, firstEnd.dy);
//     // path.lineTo(size.width, 0);
//     return path;
//   }

//   @override
//   bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
//     return false;
//   }
// }

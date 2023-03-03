import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/const/custom_textstyle.dart';
import 'package:reintechnik/const/enum.dart';
import 'package:reintechnik/providers/ble_provider.dart';
import 'package:reintechnik/screens/home/widgets/device_listview.dart';
import 'package:reintechnik/utils/widgets/custom_buttom.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BLEProvider>(context);
    return Scaffold(
      body: StreamBuilder(
        stream: provider.bleStatusStream,
        builder: (context, snapshot) {
          if (snapshot.data == BLEStatus.INITIAL) {
            return DeviceListView(bleDeviceList: provider.bleDeviceList);
          } else if (snapshot.data == BLEStatus.ERROR &&
              snapshot.data == BLEStatus.ERROR_NO_DEVICES) {
            return const ScanWidget(
              title: "Error when connect try to scan and conenct again",
            );
          } else if (snapshot.data == BLEStatus.CONNECTED) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Text(
                    "${provider.bluetoothDevice?.name} is connected.Let's Control",
                  ),
                ),
                const SizedBox(height: 10),
                CustomButton(
                  title: 'Scan wifi',
                  onTap: () {
                    provider.scanDevice();
                  },
                  enable: true,
                ),
              ],
            );
          } else {
            return const ScanWidget(
              title: "No device connect try to scan again",
            );
          }
        },
      ),
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}

class ScanWidget extends StatelessWidget {
  const ScanWidget({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BLEProvider>(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Text(
            title,
            style: CustomTextStyle.h4Medium,
          ),
        ),
        const SizedBox(height: 12),
        CustomButton(
          title: "   Scan   ",
          onTap: () {
            provider.scanDevice();
          },
          enable: true,
        )
      ],
    );
  }
}

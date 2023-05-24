import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/const/custom_textstyle.dart';
import 'package:reintechnik/const/enum.dart';
import 'package:reintechnik/providers/app_provider.dart';
import 'package:reintechnik/screens/home/home_screen.dart';
import 'package:reintechnik/screens/home/widgets/device_listview.dart';
import 'package:reintechnik/screens/home/widgets/local_device.dart';

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const ExpansionTile(
            title: Text(
              "Kết nối Bluetooth",
              style: CustomTextStyle.h3Medium,
            ),
            children: [SizedBox(height: 500, child: BleDeviceView())],
          ),
          ExpansionTile(
            title: const Text(
              "Kết nối  với thiết bị local",
              style: CustomTextStyle.h3Medium,
            ),
            children: [
              SizedBox(
                height: 500,
                child: Consumer<AppProvider>(
                  builder: (context, value, child) => value.socketTCP != null
                      ? const ConnectedLocalDeviceWidget()
                      : const LocalDevicWidget(),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

class BleDeviceView extends StatelessWidget {
  const BleDeviceView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    return StreamBuilder(
      stream: provider.bleStatusStream,
      builder: (context, snapshot) {
        if (snapshot.data == BLEStatus.INITIAL) {
          return DeviceListView(bleDeviceList: provider.bleDeviceList);
        } else if (snapshot.data == BLEStatus.SCANNING) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.data == BLEStatus.ERROR &&
            snapshot.data == BLEStatus.ERROR_NO_DEVICES) {
          return const ScanWidget(
            title: "Error when connect try to scan and conenct again",
          );
        } else if (snapshot.data == BLEStatus.CONNECTED) {
          return const WifiListWidget();
        } else {
          return const ScanWidget(
            title: "No device connect try to scan again",
          );
        }
      },
    );
  }
}

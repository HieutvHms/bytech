import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/const/enum.dart';
import 'package:reintechnik/providers/ble_provider.dart';
import 'package:reintechnik/screens/home/widgets/device_listview.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<BLEProvider>(
        builder: (context, value, child) {
          return StreamBuilder(
            stream: value.bleStatusStream,
            builder: (context, snapshot) {
              if (snapshot.data == BLEStatus.INITIAL) {
                return DeviceListView(bleDeviceList: value.bleDeviceList);
              } else if (snapshot.data == BLEStatus.ERROR &&
                  snapshot.data == BLEStatus.ERROR_NO_DEVICES) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Center(
                      child: Text(
                          'Error when connect try to scan and conenct again'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        value.scanDevice();
                      },
                      child: const Text("Scan"),
                    )
                  ],
                );
              } else if (snapshot.data == BLEStatus.CONNECTED) {
                return Center(
                    child: Text("${value.bluetoothDevice?.name} is connected"));
              } else {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Center(
                      child: Text('No device try to scan again'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        value.scanDevice();
                      },
                      child: const Text("Scan"),
                    )
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/providers/ble_provider.dart';

class DeviceListView extends StatelessWidget {
  const DeviceListView({super.key, required this.bleDeviceList});
  final List<BluetoothDevice> bleDeviceList;
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(bleDeviceList[index].name),
          ElevatedButton(
            onPressed: () {
              final provider = Provider.of<BLEProvider>(context, listen: false);
              provider.connectToDevice(bleDeviceList[index]);
            },
            child: const Text('Connect to device'),
          ),
        ],
      ),
      itemCount: bleDeviceList.length,
    );
  }
}

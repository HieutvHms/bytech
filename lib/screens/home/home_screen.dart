import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/providers/ble_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<BLEProvider>(
        builder: (context, value, child) {
          return value.bluetoothDevice != null
              ? Center(
                  child: Text("${value.bluetoothDevice!.name} is connected"),
                )
              : (value.bleDeviceList.isEmpty
                  ? Center(
                      child: ElevatedButton(
                        onPressed: () {
                          value.scanDevice();
                        },
                        child: const Text("Start scan"),
                      ),
                    )
                  : ListView.builder(
                      itemBuilder: (context, index) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(value.bleDeviceList[index].name),
                          ElevatedButton(
                            onPressed: () {
                              value.connectToDevice(value.bleDeviceList[index]);
                            },
                            child: const Text('Connect to device'),
                          ),
                        ],
                      ),
                      itemCount: value.bleDeviceList.length,
                    ));
        },
      ),
    );
  }
}

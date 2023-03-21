import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/providers/app_provider.dart';
import 'package:reintechnik/utils/widgets/custom_buttom.dart';

class DeviceListView extends StatelessWidget {
  const DeviceListView({super.key, required this.bleDeviceList});
  final List<BluetoothDevice> bleDeviceList;
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    return RefreshIndicator(
      onRefresh: () async {
        await provider.scanDevice();
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemBuilder: (context, index) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(bleDeviceList[index].name),
              CustomButton(
                title: "Connect",
                onTap: () {
                  provider.connectToDevice(bleDeviceList[index]);
                },
                enable: true,
              ),
            ],
          ),
          itemCount: bleDeviceList.length,
          separatorBuilder: (context, index) {
            return const Divider();
          },
        ),
      ),
    );
  }
}

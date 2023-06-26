import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/const/asset_const.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';
import 'package:reintechnik/const/enum.dart';
import 'package:reintechnik/new_screen/controller_screen/new_controller_screen.dart';
import 'package:reintechnik/new_screen/home/home_screen.dart';
import 'package:reintechnik/providers/app_provider.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Scaffold(
      backgroundColor: CustomColor.neutralWhite90,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: CustomColor.neutralWhite90,
        title: const Center(
          child: Text(
            "Connect",
            style: CustomTextStyle.h4Medium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              ExpansionTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                collapsedBackgroundColor: CustomColor.neutralWhite,
                backgroundColor: CustomColor.neutralWhite,
                onExpansionChanged: (value) {
                  if (value == true) {
                    provider.scanDevice();
                  }
                },
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
                  // const BluetoothWarning(),
                  StreamBuilder(
                    stream: provider.bleStatusStream,
                    builder: (context, snapshot) {
                      if (snapshot.data == BLEStatus.INITIAL) {
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: ListView.separated(
                            itemBuilder: (ctx, index) => DeviceConnectCard(
                              connect: () async {
                                await provider
                                    .connectToDevice(
                                  provider.bleDeviceList[index],
                                )
                                    .then((value) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => NewControllerScreen(
                                        deviceParam: DeviceParam(
                                          deviceName: provider
                                              .bleDeviceList[index].name,
                                          connectStatus: ConnectStatus.BLE,
                                        ),
                                        connectType: ConnectType.bluetooth,
                                      ),
                                    ),
                                  );
                                });
                              },
                              devicename: provider.bleDeviceList[index].name,
                            ),
                            itemCount: provider.bleDeviceList.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                          ),
                        );
                      } else if (snapshot.data == BLEStatus.SCANNING) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      } else if (snapshot.data == BLEStatus.ERROR &&
                          snapshot.data == BLEStatus.ERROR_NO_DEVICES) {
                        return const Text(
                            'Error when connect try to scan and conenct again');
                      } else if (snapshot.data == BLEStatus.CONNECTED) {
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: ListView.separated(
                            itemBuilder: (ctx, index) => DeviceConnectCard(
                              connect: () async {
                                await provider.connectToDevice(
                                  provider.bleDeviceList[index],
                                );
                              },
                              devicename: provider.bleDeviceList[index].name,
                            ),
                            itemCount: provider.bleDeviceList.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                          ),
                        );
                      } else if (snapshot.data == BLEStatus.BLUE_TOOTH_IS_OFF) {
                        return const BluetoothWarning();
                      } else {
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: ListView.separated(
                            itemBuilder: (ctx, index) => DeviceConnectCard(
                              connect: () async {
                                await provider.connectToDevice(
                                  provider.bleDeviceList[index],
                                );
                              },
                              devicename: provider.bleDeviceList[index].name,
                            ),
                            itemCount: provider.bleDeviceList.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                          ),
                        );
                      }
                    },
                  )
                ],
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                collapsedBackgroundColor: CustomColor.neutralWhite,
                backgroundColor: CustomColor.neutralWhite,
                onExpansionChanged: (value) {
                  if (value == true) {
                    provider.scanLocalService();
                  }
                },
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
                  Consumer<AppProvider>(
                    builder: (context, consumer, child) => SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: StreamBuilder(
                          stream: provider.mdnsStatusStream,
                          builder: (ctx, snapShot) {
                            if (snapShot.data == MDNSStatus.SCANING) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            } else if (snapShot.data == MDNSStatus.DONE_SCAN) {
                              return ListView.separated(
                                itemBuilder: (ctx, index) => DeviceConnectCard(
                                  connect: () async {
                                    await provider
                                        .connectSocket(
                                      context,
                                      consumer.localService[index].host ?? '',
                                      consumer.localService[index].port ?? 2000,
                                      consumer.localService[index].name ?? "",
                                    )
                                        .then((value) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => NewControllerScreen(
                                            deviceParam: DeviceParam(
                                              deviceName: consumer
                                                      .localService[index]
                                                      .name ??
                                                  "",
                                              connectStatus:
                                                  ConnectStatus.SOCKET,
                                            ),
                                            connectType: ConnectType.mdns,
                                          ),
                                        ),
                                      );
                                    });
                                  },
                                  devicename:
                                      consumer.localService[index].name ?? "",
                                ),
                                itemCount: consumer.localService.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(),
                              );
                            } else {
                              return const WifiWarning();
                            }
                          }),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

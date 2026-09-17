import 'package:flutter/material.dart';
import 'package:new_renitek/const/asset_const.dart';
import 'package:new_renitek/const/custom_color.dart';
import 'package:new_renitek/const/custom_textstyle.dart';
import 'package:new_renitek/const/enum.dart';
import 'package:new_renitek/new_screen/controller_screen/new_controller_screen.dart';
import 'package:new_renitek/new_screen/home/home_screen.dart';
import 'package:new_renitek/providers/app_provider.dart';
import 'package:new_renitek/service/offline_ota_service.dart';
import 'package:provider/provider.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    // Tự động đồng bộ Firmware khi mở App
    OfflineOTAService.syncFirmwareBackground();
  }

  @override
  void dispose() {
    super.dispose();
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Chỉ hiển thị quét BLE khi bật chế độ Expert Mode
              if (provider.isExpertMode)
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
                      // BleScanner(
                      //     ble: ble,
                      //     logMessage: (String message) {
                      //       print(message);
                      //     }).startScan([]);
                      provider.scanDevice();
                    }
                  },
                  expandedCrossAxisAlignment: CrossAxisAlignment.center,
                  title: const Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: AssetImage(AssetConst.bluetoothIcon),
                        radius: 12,
                        backgroundColor: CustomColor.neutralWhite96,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bluetooth connections',
                          style: CustomTextStyle.h5Medium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    // const BluetoothWarning(),
                    StreamBuilder(
                      stream: provider.bleStatusStream,
                      builder: (context, snapshot) {
                        if (snapshot.data == BLEStatus.INITIAL) {
                          print(
                              'UI: BLE Status INITIAL, device count: ${provider.bleDeviceList.length}');
                          if (provider.bleDeviceList.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(10),
                              child: Center(
                                child: Text(
                                    'No devices found. Pull to scan again.'),
                              ),
                            );
                          }
                          print(
                              'UI: Creating ListView with ${provider.bleDeviceList.length} devices');
                          return SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: ListView.separated(
                              itemBuilder: (ctx, index) {
                                print('UI: Building item $index');

                                // Tính toán tên thiết bị hiển thị chuẩn
                                final originalName =
                                    provider.bleDeviceList[index].name;
                                final savedName =
                                    provider.renameMap[originalName];
                                final displayDeviceName = savedName ??
                                    (originalName.isNotEmpty
                                        ? originalName
                                        : 'Unknown Device (${provider.bleDeviceList[index].id.substring(0, 8)}...)');

                                return DeviceConnectCard(
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
                                              deviceName: displayDeviceName,
                                              connectStatus: ConnectStatus.BLE,
                                            ),
                                            connectType: ConnectType.bluetooth,
                                          ),
                                        ),
                                      );
                                    });
                                  },
                                  devicename: displayDeviceName,
                                );
                              },
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
                                                    .bluetoothDevice?.name ??
                                                "",
                                            connectStatus: ConnectStatus.BLE,
                                          ),
                                          connectType: ConnectType.bluetooth,
                                        ),
                                      ),
                                    );
                                  });
                                },
                                devicename: provider.renameMap[
                                        provider.bleDeviceList[index].name] ??
                                    (provider.bleDeviceList[index].name
                                            .isNotEmpty
                                        ? provider.bleDeviceList[index].name
                                        : 'Unknown Device (${provider.bleDeviceList[index].id.substring(0, 8)}...)'),
                              ),
                              itemCount: provider.bleDeviceList.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(),
                            ),
                          );
                        } else if (snapshot.data ==
                            BLEStatus.BLUE_TOOTH_IS_OFF) {
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
                                devicename: provider.renameMap[
                                        provider.bleDeviceList[index].name] ??
                                    (provider.bleDeviceList[index].name
                                            .isNotEmpty
                                        ? provider.bleDeviceList[index].name
                                        : 'Unknown Device (${provider.bleDeviceList[index].id.substring(0, 8)}...)'),
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
                title: const Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: AssetImage(AssetConst.wifiIcon),
                      radius: 12,
                      backgroundColor: CustomColor.neutralWhite96,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Wifi connections',
                        style: CustomTextStyle.h5Medium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                                      consumer.localService[index].host ??
                                          '192.168.1.1',
                                      //consumer.localService[index].port ?? 2000,
                                      23, // Cổng TCP thực sự của Firmware (đã xác nhận) thay vì lấy mDNS (cổng 80)
                                      consumer.localService[index].name ?? "",
                                    )
                                        .then((value) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => NewControllerScreen(
                                            deviceParam: DeviceParam(
                                              deviceName: consumer.renameMap[
                                                      consumer
                                                          .localService[index]
                                                          .name] ??
                                                  consumer
                                                      .localService[index].name,
                                              connectStatus:
                                                  ConnectStatus.SOCKET,
                                            ),
                                            connectType: ConnectType.mdns,
                                          ),
                                        ),
                                      );
                                    });
                                  },
                                  devicename: consumer.renameMap[
                                          consumer.localService[index].name] ??
                                      consumer.localService[index].name ??
                                      "",
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

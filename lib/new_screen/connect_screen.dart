import 'package:flutter/material.dart';
import 'package:new_renitek/const/asset_const.dart';
import 'package:new_renitek/const/custom_color.dart';
import 'package:new_renitek/const/custom_textstyle.dart';
import 'package:new_renitek/const/enum.dart';
import 'package:new_renitek/new_screen/controller_screen/new_controller_screen.dart';
import 'package:new_renitek/new_screen/home/home_screen.dart';
import 'package:new_renitek/providers/app_provider.dart';
import 'package:new_renitek/providers/mixins/app_provider_state.dart'
    show ConnectStatus, MDNSStatus;
import 'package:new_renitek/service/offline_ota_service.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:new_renitek/service/wifi_iot_service.dart';
import 'package:new_renitek/utils/dialog_helper.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _isWifiExpanded = false;

  void _handleScanWifiAP(BuildContext context, AppProvider provider) async {
    bool isWifiEnabled = await WifiIotService.checkIfWifiEnabled();
    if (!isWifiEnabled) {
      if (context.mounted) {
        DialogHelper.showCustomDialog(
          context: context,
          title: 'WiFi is Off',
          content: const Text(
            "Please turn on WiFi to scan for new devices.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (btnCtx) => OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(btnCtx),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (btnCtx) => FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: CustomColor.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(btnCtx);
                        AppSettings.openAppSettings(type: AppSettingsType.wifi);
                      },
                      child: const Text('Open Setting',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }
      return;
    }

    provider.scanDeviceWifiAP();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.only(top: 10, bottom: 24),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Text("Select Device AP to connect",
                    style: CustomTextStyle.h5Medium),
              ),
              const Divider(),
              Expanded(
                child: Consumer<AppProvider>(
                  builder: (ctx, apConsumer, _) {
                    if (apConsumer.isScanningDeviceWifi) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (apConsumer.deviceWifiList.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('No unconfigured devices found'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => apConsumer.scanDeviceWifiAP(),
                              child: const Text('Rescan'),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: apConsumer.deviceWifiList.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final network = apConsumer.deviceWifiList[i];
                        return ListTile(
                          title: Text(network.ssid ?? "Unknown",
                              style: CustomTextStyle.bodyMedium,
                              overflow: TextOverflow.ellipsis),
                          subtitle:
                              const Text("Tap to connect phone to device"),
                          trailing: const Icon(Icons.wifi),
                          onTap: () async {
                            final ssid = network.ssid ?? "";

                            void showPasswordDialog([String initialPwd = '']) {
                              TextEditingController pwController =
                                  TextEditingController(text: initialPwd);
                              bool obscurePwd = true;
                              DialogHelper.showCustomDialog(
                                context: bottomSheetContext,
                                content: StatefulBuilder(
                                  builder: (context, setState) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.wifi_lock,
                                                color:
                                                    CustomColor.primaryColor),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                  ssid.isEmpty
                                                      ? "Unknown"
                                                      : ssid,
                                                  style:
                                                      CustomTextStyle.h5Medium,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: pwController,
                                                obscureText: obscurePwd,
                                                decoration: InputDecoration(
                                                  hintText: 'Mật khẩu WiFi',
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  suffixIcon: IconButton(
                                                    icon: Icon(obscurePwd
                                                        ? Icons.visibility_off
                                                        : Icons.visibility),
                                                    onPressed: () {
                                                      setState(() {
                                                        obscurePwd =
                                                            !obscurePwd;
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Builder(
                                                builder: (btnCtx) =>
                                                    OutlinedButton(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.grey[700],
                                                    side: BorderSide(
                                                        color:
                                                            Colors.grey[300]!),
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 8),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(btnCtx),
                                                  child: const Text('Cancel',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Builder(
                                                builder: (btnCtx) =>
                                                    FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: CustomColor
                                                        .primaryColor,
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 8),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pop(btnCtx);
                                                    DialogHelper
                                                        .showCustomDialog(
                                                      context:
                                                          bottomSheetContext,
                                                      barrierDismissible: false,
                                                      content: const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    );
                                                    apConsumer
                                                        .connectToDeviceWifiAP(
                                                            ssid,
                                                            pwController.text)
                                                        .then((success) {
                                                      if (bottomSheetContext
                                                          .mounted) {
                                                        Navigator.pop(
                                                            bottomSheetContext); // close loading
                                                      }
                                                      if (success &&
                                                          bottomSheetContext
                                                              .mounted) {
                                                        Navigator.pop(
                                                            bottomSheetContext); // close bottom sheet
                                                      }
                                                    });
                                                  },
                                                  child: const Text('Connect',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            }

                            final savedPwd =
                                await WifiIotService.getSavedWifiPassword(ssid);

                            if (savedPwd != null && savedPwd.isNotEmpty) {
                              DialogHelper.showCustomDialog(
                                context: bottomSheetContext,
                                barrierDismissible: false,
                                content: const Center(
                                    child: CircularProgressIndicator()),
                              );

                              final success = await apConsumer
                                  .connectToDeviceWifiAP(ssid, savedPwd);

                              if (bottomSheetContext.mounted) {
                                Navigator.pop(
                                    bottomSheetContext); // close loading
                              }

                              if (success) {
                                if (bottomSheetContext.mounted) {
                                  Navigator.pop(
                                      bottomSheetContext); // close bottom sheet
                                }
                              } else {
                                // Nếu mật khẩu cũ sai (kết nối thất bại), mở bảng nhập lại mk
                                showPasswordDialog(savedPwd);
                              }
                            } else {
                              showPasswordDialog();
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
                  setState(() => _isWifiExpanded = value);
                  if (value == true) {
                    provider.scanLocalService();
                  }
                },
                title: Row(
                  children: [
                    const CircleAvatar(
                      backgroundImage: AssetImage(AssetConst.wifiIcon),
                      radius: 12,
                      backgroundColor: CustomColor.neutralWhite96,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Wifi connections',
                        style: CustomTextStyle.h5Medium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isWifiExpanded && Platform.isAndroid)
                      Consumer<AppProvider>(builder: (ctx, apConsumer, _) {
                        return TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor:
                                CustomColor.primaryColor.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: apConsumer.isScanningDeviceWifi
                              ? null
                              : () => _handleScanWifiAP(context, provider),
                          child: apConsumer.isScanningDeviceWifi
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Scan',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: CustomColor.primaryColor)),
                        );
                      }),
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
                                      consumer.localService[index].host ?? "",
                                      //consumer.localService[index].port ?? 2000,
                                      23, // Cổng TCP thực sự của Firmware
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
                              return const Center(
                                  child:
                                      Text("No local network devices found"));
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

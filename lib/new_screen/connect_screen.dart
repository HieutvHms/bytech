import 'package:flutter/material.dart';
import 'package:new_renitek/const/asset_const.dart';
import 'package:new_renitek/const/custom_color.dart';
import 'package:new_renitek/const/custom_textstyle.dart';
import 'package:new_renitek/const/enum.dart';
import 'package:new_renitek/new_screen/controller_screen/new_controller_screen.dart';
import 'package:new_renitek/new_screen/home/home_screen.dart';
import 'package:new_renitek/providers/app_provider.dart';
import 'package:new_renitek/providers/mixins/app_provider_state.dart';
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
  @override
  void initState() {
    super.initState();
    // Tự động đồng bộ Firmware khi mở App
    OfflineOTAService.syncFirmwareBackground();
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
              if (provider.isExpertMode) const _BleConnectionSection(),
              const SizedBox(height: 8),
              const _WifiConnectionSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// WIDGETS
class _BleConnectionSection extends StatelessWidget {
  const _BleConnectionSection();

  void _navigateToController(BuildContext context, String deviceName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewControllerScreen(
          deviceParam: DeviceParam(
            deviceName: deviceName,
            connectStatus: ConnectStatus.BLE,
          ),
          connectType: ConnectType.bluetooth,
        ),
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, AppProvider provider) {
    if (provider.bleDeviceList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: Center(
          child: Text('No devices found. Pull to scan again.'),
        ),
      );
    }
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: ListView.separated(
        itemCount: provider.bleDeviceList.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (ctx, index) {
          final originalName = provider.bleDeviceList[index].name;
          final savedName = provider.renameMap[originalName];
          final displayDeviceName = savedName ??
              (originalName.isNotEmpty
                  ? originalName
                  : 'Unknown Device (${provider.bleDeviceList[index].id.substring(0, 8)}...)');

          return DeviceConnectCard(
            devicename: displayDeviceName,
            connect: () async {
              await provider
                  .connectToDevice(provider.bleDeviceList[index])
                  .then((_) {
                _navigateToController(context, displayDeviceName);
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    return ExpansionTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      collapsedBackgroundColor: CustomColor.neutralWhite,
      backgroundColor: CustomColor.neutralWhite,
      onExpansionChanged: (value) {
        if (value) {
          provider.scanDevice();
        }
      },
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
        StreamBuilder(
          stream: provider.bleStatusStream,
          builder: (context, snapshot) {
            final status = snapshot.data;
            if (status == BLEStatus.INITIAL || status == BLEStatus.CONNECTED) {
              return _buildDeviceList(context, provider);
            } else if (status == BLEStatus.SCANNING) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (status == BLEStatus.ERROR ||
                status == BLEStatus.ERROR_NO_DEVICES) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Error when connect try to scan and conenct again'),
              );
            } else if (status == BLEStatus.BLUE_TOOTH_IS_OFF) {
              return const BluetoothWarning();
            } else {
              return _buildDeviceList(context, provider);
            }
          },
        )
      ],
    );
  }
}

class _WifiConnectionSection extends StatefulWidget {
  const _WifiConnectionSection();

  @override
  State<_WifiConnectionSection> createState() => _WifiConnectionSectionState();
}

class _WifiConnectionSectionState extends State<_WifiConnectionSection> {
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
      builder: (bottomSheetContext) => _WifiApBottomSheet(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    return ExpansionTile(
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
        if (value) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: CustomColor.primaryColor.withOpacity(0.1),
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
                        child: CircularProgressIndicator(strokeWidth: 2))
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
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapShot.data == MDNSStatus.DONE_SCAN) {
                    return ListView.separated(
                      itemCount: consumer.localService.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (ctx, index) {
                        final service = consumer.localService[index];
                        final devicename = consumer.renameMap[service.name] ??
                            service.name ??
                            "";

                        return DeviceConnectCard(
                          devicename: devicename,
                          connect: () async {
                            await provider
                                .connectSocket(
                              context,
                              service.host ?? "",
                              23, // Cổng TCP thực sự của Firmware
                              service.name ?? "",
                            )
                                .then((value) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => NewControllerScreen(
                                    deviceParam: DeviceParam(
                                      deviceName: devicename,
                                      connectStatus: ConnectStatus.SOCKET,
                                    ),
                                    connectType: ConnectType.mdns,
                                  ),
                                ),
                              );
                            });
                          },
                        );
                      },
                    );
                  } else {
                    return const Center(
                        child: Text("No local network devices found"));
                  }
                }),
          ),
        ),
      ],
    );
  }
}

class _WifiApBottomSheet extends StatelessWidget {
  final AppProvider provider;

  const _WifiApBottomSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
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
                    final ssid = network.ssid ?? "";
                    return ListTile(
                      title: Text(ssid.isEmpty ? "Unknown" : ssid,
                          style: CustomTextStyle.bodyMedium,
                          overflow: TextOverflow.ellipsis),
                      subtitle: const Text("Tap to connect phone to device"),
                      trailing: const Icon(Icons.wifi),
                      onTap: () => _handleNetworkTap(context, apConsumer, ssid),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNetworkTap(
      BuildContext context, AppProvider apConsumer, String ssid) async {
    final savedPwd = await WifiIotService.getSavedWifiPassword(ssid);
    if (savedPwd != null && savedPwd.isNotEmpty) {
      if (!context.mounted) return;
      DialogHelper.showCustomDialog(
        context: context,
        barrierDismissible: false,
        content: const Center(child: CircularProgressIndicator()),
      );

      final success = await apConsumer.connectToDeviceWifiAP(ssid, savedPwd);

      if (context.mounted) {
        Navigator.pop(context); // close loading
      }

      if (success) {
        if (context.mounted) {
          Navigator.pop(context); // close bottom sheet
        }
      } else {
        if (context.mounted) {
          _showPasswordDialog(context, apConsumer, ssid, savedPwd);
        }
      }
    } else {
      if (context.mounted) {
        _showPasswordDialog(context, apConsumer, ssid, '');
      }
    }
  }

  void _showPasswordDialog(BuildContext context, AppProvider apConsumer,
      String ssid, String initialPwd) {
    TextEditingController pwController =
        TextEditingController(text: initialPwd);
    bool obscurePwd = true;

    DialogHelper.showCustomDialog(
      context: context,
      content: StatefulBuilder(
        builder: (dialogCtx, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_lock, color: CustomColor.primaryColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(ssid.isEmpty ? "Unknown" : ssid,
                        style: CustomTextStyle.h5Medium,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pwController,
                obscureText: obscurePwd,
                decoration: InputDecoration(
                  hintText: 'Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscurePwd ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        obscurePwd = !obscurePwd;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: CustomColor.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        DialogHelper.showCustomDialog(
                          context: context,
                          barrierDismissible: false,
                          content:
                              const Center(child: CircularProgressIndicator()),
                        );
                        apConsumer
                            .connectToDeviceWifiAP(ssid, pwController.text)
                            .then((success) {
                          if (context.mounted) {
                            Navigator.pop(context); // close loading
                          }
                          if (success && context.mounted) {
                            Navigator.pop(context); // close bottom sheet
                          }
                        });
                      },
                      child: const Text('Connect',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
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
}

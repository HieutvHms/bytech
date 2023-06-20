import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/const/asset_const.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';
import 'package:reintechnik/models/wifi.dart';
import 'package:reintechnik/new_screen/home/home_screen.dart';
import 'package:reintechnik/providers/app_provider.dart';
import 'package:reintechnik/utils/widgets/custom_buttom.dart';

class DeviceParam {
  final String deviceName;
  final ConnectStatus connectStatus;

  DeviceParam({
    required this.deviceName,
    required this.connectStatus,
  });
}

enum ConnectType { bluetooth, mdns }

class NewControllerScreen extends StatelessWidget {
  const NewControllerScreen(
      {super.key, required this.deviceParam, required this.connectType});
  final DeviceParam deviceParam;
  final ConnectType connectType;
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Scaffold(
      backgroundColor: CustomColor.neutralWhite90,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: CustomColor.neutralWhite90,
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: const ImageIcon(
            AssetImage(AssetConst.backArrow),
            color: CustomColor.neutralBlack,
          ),
        ),
        title: Text(
          deviceParam.deviceName,
          style: CustomTextStyle.h4Medium,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'Information',
              style: CustomTextStyle.bodyMedium
                  .copyWith(color: CustomColor.neutralBlack50),
            ),
            const SizedBox(height: 8),
            ConnectDeviceWidget(
              deviceName: deviceParam.deviceName,
            ),
            const SizedBox(height: 42),
            Text(
              'Control',
              style: CustomTextStyle.bodyMedium
                  .copyWith(color: CustomColor.neutralBlack50),
            ),
            const SizedBox(height: 8),
            StreamBuilder(
              stream: Provider.of<AppProvider>(context).motorStatus,
              builder: (ctx, snapshot) => Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                // margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    Center(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                        child: Image.asset(AssetConst.screenImage),
                      ),
                    ),
                    const Text('Press and hold button to control device'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ControlerButton(
                          onTap: () {},
                          iconData: Icons.arrow_back,
                          title: 'Move in',
                          enable: snapshot.data?.canMoveIn() == true,
                          onLongPressStart: () {
                            provider.controlMotor(ControlType.GO_IN);
                          },
                          onLongPressEnd: () {
                            provider.controlMotor(ControlType.STOP);
                          },
                        ),
                        ControlerButton(
                          onTap: () {},
                          iconData: Icons.arrow_forward,
                          title: 'Move out',
                          enable: snapshot.data?.canMoveOut() == true,
                          onLongPressStart: () {
                            provider.controlMotor(ControlType.GO_OUT);
                          },
                          onLongPressEnd: () {
                            provider.controlMotor(ControlType.STOP);
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void showWifiSettingDialog(BuildContext context) {
    final myModel = Provider.of<AppProvider>(context, listen: false);
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      context: context,
      builder: (ctx) => ListenableProvider.value(
        value: myModel,
        child: const ConfigWifiWidget(),
      ),
    );
  }
}

class ConnectDeviceWidget extends StatelessWidget {
  const ConnectDeviceWidget(
      {super.key, required this.deviceName, this.canGoNext});
  final String deviceName;
  final bool? canGoNext;
  @override
  Widget build(BuildContext context) {
    return Container(
      // margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      width: MediaQuery.of(context).size.width * 0.9,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Consumer<AppProvider>(
        builder: (context, value, child) =>
            value.bluetoothDevice != null || value.socketTCP != null
                ? Column(
                    children: [
                      _infoRow("Device name", deviceName),
                      const Divider(),
                      _infoRow(
                        "Connection",
                        value.bluetoothDevice != null ? "BLUETOOTH" : "WIFI",
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Wifi Configuration",
                            style: CustomTextStyle.bodyLight,
                          ),
                          CustomOutLineButton(
                            title: 'Config',
                            ontap: () {
                              showWifiSettingDialog(context);
                            },
                          )
                        ],
                      )
                    ],
                  )
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No device connected yet.',
                      style: CustomTextStyle.h4Medium,
                    ),
                  ),
      ),
    );
  }
}

Widget _infoRow(String title, String name) {
  return Row(
    children: [
      Text(
        title,
        style: CustomTextStyle.bodyLight,
      ),
      const Spacer(),
      Text(
        name,
        style: CustomTextStyle.bodyMedium,
      ),
    ],
  );
}

void showWifiSettingDialog(BuildContext context) {
  final myModel = Provider.of<AppProvider>(context, listen: false);
  showModalBottomSheet(
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
    ),
    context: context,
    builder: (ctx) => ListenableProvider.value(
      value: myModel,
      child: const ConfigWifiWidget(),
    ),
  );
}

class ConfigWifiWidget extends StatefulWidget {
  const ConfigWifiWidget({
    super.key,
  });
  // final AppProvider provider;
  @override
  State<ConfigWifiWidget> createState() => _ConfigWifiWidgetState();
}

class _ConfigWifiWidgetState extends State<ConfigWifiWidget> {
  // late AppProvider provider;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // provider = context.watch<AppProvider>();
    // provider.scanWifi();
  }

  void showConfigWifi(Wifi wifi, AppProvider provider) {
    final wifiCtrl = TextEditingController(text: wifi.name);
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              const Text('Wifi'),
              const SizedBox(height: 8),
              InputInfoWidget(
                editingController: wifiCtrl,
                enabled: false,
              ),
              const SizedBox(height: 12),
              const Text('Password'),
              const SizedBox(height: 8),
              InputInfoWidget(
                editingController: passCtrl,
                enabled: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomOutLineButton(
                      ontap: () {
                        Navigator.of(ctx).pop();
                      },
                      title: "Cancel",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      title: 'Save',
                      onTap: () {
                        provider.confiWifi(
                          Wifi(
                            name: wifiCtrl.text,
                            password: passCtrl.text,
                          ),
                        );
                        Navigator.of(ctx).pop();
                      },
                      enable: true,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(),
            const Text('Device configuration'),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.close),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Text(
              'Select Wifi connection from below list',
              style: CustomTextStyle.captionMedium,
            ),
            GestureDetector(
              onTap: () {
                provider.scanWifi();
              },
              child: Row(
                children: const [
                  ImageIcon(
                    AssetImage(AssetConst.syncIcon),
                    color: CustomColor.primaryColor,
                  ),
                  Text(
                    'Scan',
                    style: TextStyle(color: CustomColor.primaryColor),
                  )
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: CustomColor.neutralWhite90,
          ),
          child: StreamBuilder(
            stream: provider.wifiConnectStatusStream,
            builder: (ctx, snapShot) => Consumer<AppProvider>(
              builder: (_, appProvider, __) => ListView.builder(
                itemBuilder: (ctx, index) => GestureDetector(
                  onTap: () {
                    showConfigWifi(appProvider.wifiList[index], appProvider);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: snapShot.data?.ssidNameConnect !=
                            appProvider.wifiList[index].name
                        ? Text(
                            appProvider.wifiList[index].name,
                            style: CustomTextStyle.bodyMedium,
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                appProvider.wifiList[index].name,
                                style: CustomTextStyle.bodyMedium,
                              ),
                              snapShot.data!.getStatusTextWifi(),
                            ],
                          ),
                  ),
                ),
                itemCount: appProvider.wifiList.length,
              ),
            ),
          ),
        )
      ],
    );
  }
}

class InputInfoWidget extends StatelessWidget {
  const InputInfoWidget(
      {super.key, required this.enabled, this.editingController});
  final bool enabled;
  final TextEditingController? editingController;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      width: double.maxFinite,
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: CustomColor.neutralWhite90),
      child: TextField(
        controller: editingController,
        enabled: enabled,
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }
}

class ControlerButton extends StatelessWidget {
  const ControlerButton(
      {super.key,
      required this.title,
      required this.onTap,
      required this.iconData,
      this.onLongPressStart,
      this.onLongPressEnd,
      required this.enable});
  final String title;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final IconData iconData;
  final bool enable;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (enable) {
          onTap();
        }
      },
      onLongPressDown: (s) {
        if (enable && onLongPressStart != null) {
          onLongPressStart!();
        }
      },
      onLongPressUp: () {
        if (enable && onLongPressEnd != null) {
          onLongPressEnd!();
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // borderRadius: BorderRadius.circular(60),
              border: Border.all(
                color: enable
                    ? CustomColor.primaryColor
                    : CustomColor.neutralBlack50,
                width: 4,
              ),
            ),
            child: Icon(
              iconData,
              color: enable
                  ? CustomColor.primaryColor
                  : CustomColor.neutralBlack50,
              size: 30,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: CustomTextStyle.bodyMedium,
          )
        ],
      ),
    );
  }
}

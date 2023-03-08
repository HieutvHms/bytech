import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/const/custom_textstyle.dart';
import 'package:reintechnik/const/enum.dart';
import 'package:reintechnik/models/wifi.dart';
import 'package:reintechnik/providers/ble_provider.dart';
import 'package:reintechnik/screens/home/widgets/device_listview.dart';
import 'package:reintechnik/utils/widgets/custom_buttom.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BLEProvider>(context);
    return Scaffold(
      body: StreamBuilder(
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
      ),
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}

class ScanWidget extends StatelessWidget {
  const ScanWidget({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BLEProvider>(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Text(
            title,
            style: CustomTextStyle.h4Medium,
          ),
        ),
        const SizedBox(height: 12),
        CustomButton(
          title: "   Scan   ",
          onTap: () {
            provider.scanDevice();
          },
          enable: true,
        )
      ],
    );
  }
}

class ConfigWifiWidget extends StatelessWidget {
  const ConfigWifiWidget({super.key, required this.wifi});
  final Wifi wifi;
  @override
  Widget build(BuildContext context) {
    final wifiPassTextController = TextEditingController();
    final provider = Provider.of<BLEProvider>(context, listen: false);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cài đặt mật khẩu cho ${wifi.name}',
              style: CustomTextStyle.h4Regular,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: wifiPassTextController,
              decoration: const InputDecoration(
                  hintText: "Vui lòng nhập mật khẩu cho wifi"),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                CustomButton(
                  title: "Hủy",
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  enable: true,
                ),
                const SizedBox(width: 16),
                CustomButton(
                  title: "Xác nhận",
                  onTap: () {
                    provider.confiWifi(wifi.copywith(
                        fillPassword: wifiPassTextController.text));
                    Navigator.of(context).pop();
                  },
                  enable: true,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class WifiListWidget extends StatelessWidget {
  const WifiListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BLEProvider>(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 30),
        Center(
          child: Text(
            "${provider.bluetoothDevice?.name} is connected.Let's Control",
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder(
            stream: provider.wifiStatusStream,
            builder: (context, snapshot) {
              return CustomButton(
                title: 'Scan wifi',
                onTap: () {
                  provider.scanWifi();
                },
                enable: true,
                isLoading: snapshot.data == WifiStatus.SCANNING,
              );
            }),
        Expanded(
          child: ListView.separated(
            itemBuilder: (ctx, index) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(provider.wifiList[index].name),
                  CustomButton(
                    title: "Config",
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (ctx) {
                            return ConfigWifiWidget(
                              wifi: provider.wifiList[index],
                            );
                          });
                    },
                    enable: true,
                  )
                ]),
            itemCount: provider.wifiList.length,
            separatorBuilder: (BuildContext context, int index) {
              return const Divider();
            },
          ),
        )
      ],
    );
  }
}

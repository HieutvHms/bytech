import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/utils/widgets/custom_buttom.dart';

import '../../../providers/app_provider.dart';

class LocalDevicWidget extends StatelessWidget {
  const LocalDevicWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (provider.localService.isEmpty)
          const Text("No local device connected try to scan"),
        const SizedBox(height: 12),
        StreamBuilder(
            stream: provider.mdnsStatusStream,
            builder: (context, snapshot) {
              return CustomButton(
                title: "Quét thiết bị",
                onTap: () {
                  provider.scanLocalService();
                },
                enable: true,
                isLoading: snapshot.data == MDNSStatus.SCANING,
              );
            }),
        const LocalDeviceList()
      ],
    );
  }
}

class ConnectedLocalDeviceWidget extends StatelessWidget {
  const ConnectedLocalDeviceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Đã kết nối tới thiết bị bạn có thể điều khiển"),
        CustomButton(
          title: 'Disconnect',
          onTap: () {
            provider.disconnectTCP();
          },
          enable: true,
        )
      ],
    );
  }
}

class LocalDeviceList extends StatelessWidget {
  const LocalDeviceList({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Consumer<AppProvider>(
      builder: (context, value, child) => SingleChildScrollView(
        child: Column(
          children: value.localService
              .map((localService) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          localService.name ?? "",
                          maxLines: 2,
                        ),
                      ),
                      CustomButton(
                        title: 'Connect',
                        onTap: () {
                          provider.connectSocket(
                            context,
                            localService.host ?? "",
                            localService.port ?? 80,
                          );
                        },
                        enable: true,
                      )
                    ]),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:new_renitek/const/enum.dart';
import 'package:new_renitek/models/mdns_connected_model.dart';
import 'package:new_renitek/models/saved_device_model.dart';
import 'package:new_renitek/models/wifi.dart';
import 'package:new_renitek/providers/mixins/app_provider_state.dart';
import 'package:new_renitek/root.dart';
import 'package:new_renitek/service/offline_ota_service.dart';
import 'package:new_renitek/utils/connectivity_extention.dart';
import 'package:new_renitek/const/ble_const.dart';
import 'package:new_renitek/utils/snackbar_helper.dart';
import 'package:new_renitek/utils/show_status.dart';
import 'package:nsd/nsd.dart' as nsd;

mixin WifiSocketMixin on AppProviderState {
  @override
  void disconnectTCP() {
    socketTCP?.destroy();
    socketTCP = null;
    notifyListeners();
  }

  void scanWifi() {
    if (bluetoothCharacteristic != null) {
      wifiStatusStream = WifiStatus.SCANNING;
      final scanCommand = getScanWifiCommand();
      ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
          value: scanCommand);
      notifyListeners();
    }
  }

  void confiWifi(Wifi wifi) {
    if (bluetoothCharacteristic != null) {
      final configCommand = getConfigWifiCommand(wifi);
      print(configCommand);
      print(String.fromCharCodes(configCommand));
      ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
          value: configCommand);
    }
  }

  void scanLocalService() async {
    final isConnected = await isConnectedInternet();
    if (!isConnected) {
      mdnsStatusStream.add(MDNSStatus.NO_CONNECT);
      return;
    }
    try {
      localService = [];
      notifyListeners();
      mdnsStatusStream.add(MDNSStatus.SCANING);

      final discovery = (await mdnsService.startDiscoveryMDNS());

      discovery.addServiceListener(
        (service, status) {
          if (status == nsd.ServiceStatus.found) {
            if (!saveDeviceList
                .any((element) => element.deviceName == service.name)) {
              saveDeviceList.add(SavedDeviceModel(
                  deviceName: service.name ?? "", deviceType: DeviceType.MDNS));
            }
            if (!localService.any((element) => element.host == service.host)) {
              localService.add(service);
            }
            notifyListeners();
          }
        },
      );
      mdnsStatusStream.add(MDNSStatus.DONE_SCAN);
    } catch (e) {
      mdnsStatusStream.add(MDNSStatus.DONE_SCAN);
    }
  }

  Future<void> connectSocket(
      BuildContext context, String ip, int port, String name) async {
    try {
      disconnectBLE();
      tcpIP = ip;

      socketTCP = await socketService.connect(
        ip,
        port,
        convertDataToStatus,
      );

      try {
        print('Đang gọi HTTP GET để lấy thông tin mạch...');
        final response = await http
            .get(Uri.parse('http://$ip/status'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);

          if (jsonData['FW'] != null) {
            version = jsonData['FW'].toString();
          }
          if (jsonData['MAC'] != null) {
            String rawMac = jsonData['MAC'].toString();
            if (rawMac.contains('WIFI-')) {
              final parts = rawMac.split('WIFI-');
              if (parts.length > 1) {
                wifiApMac = parts[1].split(',')[0].trim();
              }
            } else {
              wifiApMac = rawMac.trim();
            }
          }

          print(
              'Lấy thông tin thành công: MAC=$wifiApMac, FW=$version, HW=$hardwareVersion');

          if (wifiApMac != null && wifiApMac!.isNotEmpty) {
            OfflineOTAService.saveDevice(wifiApMac!, version ?? "0.0.0");
          }
        }
      } catch (e) {}

      mdnsConnectedClient =
          MdnsConnectedClient(name: name, host: ip, port: port);

      if (globalKey.currentContext != null) {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: "Connect success",
          succcess: true,
        );
      }
      connectStatus = ConnectStatus.SOCKET;

      if (!hasAutoCheckedFirmware) {
        hasAutoCheckedFirmware = true;
        checkCurrentFirmware();
      }

      notifyListeners();

      Timer(const Duration(seconds: 2), () {
        checkCurrentFirmware();
      });
    } catch (e) {
      print('LỖI KẾT NỐI SOCKET TỚI WI-FI AP: $e');

      await Future.delayed(const Duration(seconds: 2));

      if (globalKey.currentContext != null) {
        SnackbarHelper.showError(
          globalKey.currentContext!,
          'Lỗi kết nối',
          'Không thể kết nối đến mạch điều khiển',
          duration: const Duration(seconds: 7),
        );
      }
      rethrow;
    }
  }

  List<int> getScanWifiCommand() {
    List<int> command = [];
    command.addAll(BLERequestConst.CONTROL_HEADER);
    command.addAll(BLERequestConst.SCAN_WIFI_ID);
    command.addAll(BLERequestConst.ID_PAYLOAD_DIVIVDER);
    command.addAll(BLERequestConst.FOOTER);
    return command;
  }

  List<int> getConfigWifiCommand(Wifi wifi) {
    List<int> command = [];
    command.addAll(BLERequestConst.CONTROL_HEADER);
    command.addAll(BLERequestConst.CONFIG_WIFI_ID);
    command.addAll(BLERequestConst.ID_PAYLOAD_DIVIVDER);

    final nameLength = wifi.name.length < 10
        ? "0${wifi.name.length}"
        : wifi.name.length.toString();

    command.addAll(utf8.encode(nameLength));
    command.addAll(BLERequestConst.DASH);
    command.addAll(utf8.encode(wifi.name));
    command.addAll(BLERequestConst.DASH);

    final passLength = wifi.password!.length < 10
        ? "0${wifi.password!.length}"
        : wifi.password!.length.toString();
    command.addAll(utf8.encode(passLength));
    command.addAll(BLERequestConst.DASH);
    command.addAll(utf8.encode(wifi.password!));
    command.addAll(BLERequestConst.FOOTER);
    return command;
  }
}

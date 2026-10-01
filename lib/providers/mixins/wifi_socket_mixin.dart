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
import 'package:new_renitek/const/ble_const.dart';
import 'package:new_renitek/service/storage_service.dart';
import 'package:new_renitek/utils/snackbar_helper.dart';
import 'package:new_renitek/utils/show_status.dart';
import 'package:nsd/nsd.dart' as nsd;

import 'package:new_renitek/service/wifi_iot_service.dart';

mixin WifiSocketMixin on AppProviderState {
  Future<void> scanDeviceWifiAP() async {
    isScanningDeviceWifi = true;
    deviceWifiList = [];
    notifyListeners();

    try {
      final result = await WifiIotService.scanForDeviceWifi(
          prefixes: ["AV", "Vuelogic", "NT", "bytech"]);

      if (result.isSuccess) {
        deviceWifiList = result.data;
      } else {
        if (globalKey.currentContext != null) {
          SnackbarHelper.showError(
            globalKey.currentContext!,
            'Lỗi Quét WiFi',
            result.failure.message,
          );
        }
      }
    } catch (e) {
      print("System Error in scanDeviceWifiAP: $e");
    }

    isScanningDeviceWifi = false;
    notifyListeners();
  }

  Future<bool> connectToDeviceWifiAP(String ssid, String password) async {
    bool success = await WifiIotService.connectToWifi(ssid, password: password);
    if (success) {
      // Lưu mật khẩu
      await WifiIotService.saveWifiPassword(ssid, password);
      // Sau khi kết nối thành công, bắt đầu dò mDNS
      scanLocalService();
      return true;
    } else {
      if (globalKey.currentContext != null) {
        SnackbarHelper.showError(
          globalKey.currentContext!,
          'Connection Failed',
          'Failed to connect to device WiFi',
        );
      }
      return false;
    }
  }

  @override
  void disconnectTCP() {
    socketTCP?.destroy();
    socketTCP = null;
    WifiIotService.forceWifiUsage(false);
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
    try {
      localService = [];
      notifyListeners();
      mdnsStatusStream.add(MDNSStatus.SCANING);

      // Force Android to route traffic over the current WiFi even without internet
      // await WifiIotService.forceWifiUsage(true);

      final discovery = (await mdnsService.startDiscoveryMDNS());

      discovery.addServiceListener(
        (service, status) {
          if (status == nsd.ServiceStatus.found) {
            if (!saveDeviceList
                .any((element) => element.deviceName == service.name)) {
              saveDeviceList.add(SavedDeviceModel(
                  deviceName: service.name ?? "", deviceType: DeviceType.MDNS));
              StorageService.saveDeviceList(saveDeviceList);
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
      hasAutoCheckedFirmware = false;

      var isSocketConnected = false;
      Object? socketError;
      try {
        socketTCP = await socketService.connect(
          ip,
          port,
          convertDataToStatus,
        );
        isSocketConnected = true;
      } catch (e) {
        socketTCP = null;
        socketError = e;
        print('Không kết nối được TCP socket, thử HTTP server: $e');
      }

      final isHttpConnected = await _loadDeviceStatusViaHttp(ip);

      if (!isSocketConnected && !isHttpConnected) {
        throw socketError ?? Exception('Không thể kết nối HTTP tới mạch');
      }

      mdnsConnectedClient =
          MdnsConnectedClient(name: name, host: ip, port: port);

      if (!saveDeviceList.any((element) => element.deviceName == name)) {
        saveDeviceList.add(
            SavedDeviceModel(deviceName: name, deviceType: DeviceType.MDNS));
        StorageService.saveDeviceList(saveDeviceList);
      }

      if (globalKey.currentContext != null) {
        SnackbarHelper.showSuccess(
          globalKey.currentContext!,
          '',
          'Connect success',
        );
      }
      connectStatus = ConnectStatus.SOCKET;

      if (!hasAutoCheckedFirmware) {
        hasAutoCheckedFirmware = true;
        Future.delayed(const Duration(seconds: 3), () {
          checkCurrentFirmware();
        });
      }

      notifyListeners();
    } catch (e) {
      print('LỖI KẾT NỐI SOCKET TỚI WI-FI AP: $e');

      await Future.delayed(const Duration(seconds: 2));

      if (globalKey.currentContext != null) {
        SnackbarHelper.showError(
          globalKey.currentContext!,
          'Connection Error',
          'Could not connect to the device',
          duration: const Duration(seconds: 7),
        );
      }
      rethrow;
    }
  }

  Future<bool> _loadDeviceStatusViaHttp(String ip) async {
    try {
      print('Đang gọi HTTP GET để lấy thông tin mạch...');
      final response = await http
          .get(Uri.parse('http://$ip/status'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        print('HTTP status thất bại: ${response.statusCode}');
        return false;
      }

      final jsonData = json.decode(response.body);
      if (jsonData is! Map<String, dynamic>) {
        print('HTTP status không đúng định dạng JSON object');
        return false;
      }

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
        await OfflineOTAService.saveDevice(wifiApMac!, version ?? "0.0.0");
      }
      return true;
    } catch (e) {
      print('Không lấy được thông tin mạch qua HTTP: $e');
      return false;
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

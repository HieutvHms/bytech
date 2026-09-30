import 'dart:async';
import 'dart:io';

import 'package:new_renitek/const/ble_const.dart';
import 'package:new_renitek/const/enum.dart';
import 'package:new_renitek/models/data_bulletin.dart';
import 'package:new_renitek/providers/mixins/app_provider_state.dart';
import 'package:new_renitek/root.dart';
import 'package:new_renitek/service/offline_ota_service.dart';
import 'package:new_renitek/utils/convert_data.dart';
import 'package:new_renitek/utils/get_command_byte.dart';
import 'package:new_renitek/utils/snackbar_helper.dart';

mixin DeviceControlMixin on AppProviderState {
  void controlMotor(ControlType controlType) async {
    try {
      //throw TimeoutException("Test UI Timeout");
      //throw const SocketException("Test UI Socket");
      if (connectStatus == ConnectStatus.BLE &&
          bluetoothCharacteristic != null) {
        final commandBytes = getCommandByte(controlType);
        await ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
            value: commandBytes);
      } else if (connectStatus == ConnectStatus.SOCKET &&
          socketTCP != null &&
          tcpIP != '192.168.1.1') {
        socketService.controlDevice(socketTCP!, controlType);
      } else if (connectStatus == ConnectStatus.SOCKET) {
        final commandBytes = getCommandByte(controlType);
        final ip = mdnsConnectedClient?.host ?? tcpIP;
        if (ip.isEmpty) {
          throw Exception("Unknown IP address for HTTP control");
        }
        await OfflineOTAService.controlDeviceViaHttp(ip, commandBytes);
      } else {
        if (socketTCP != null) {
          socketService.controlDevice(socketTCP!, controlType);
        }
      }
    } catch (e) {
      String thongBao = "Control device failure";
      if (e is TimeoutException) {
        thongBao = "Device is responding too slowly";
      } else if (e is SocketException) {
        thongBao = "Lost connection to the device";
      }
      if (globalKey.currentContext != null) {
        SnackbarHelper.showError(
          globalKey.currentContext!,
          'Control device failure',
          thongBao,
        );
      }
    }
  }

  @override
  void convertDataToStatus(List<int> event) {
    final bulletin = getDataBulletin(event);
    if (bulletin is WifiStatusBulletin) {
      final wifiStatus = bulletin.getWifiStatus();
      if (wifiStatus != null) {
        wifiConnectStatusStream.add(wifiStatus);
      }
    } else if (bulletin is MotorStatusBulletin) {
      final status = bulletin.getMotorStatus();
      motorStatus.add(status);
    } else if (bulletin is ScannedWifiListBulletin) {
      final wifi = bulletin.getWifiData();
      if (wifi.name.isEmpty) {
        wifiStatusStream = WifiStatus.STOP_SCAN;
      } else if (!wifiList.any((element) => wifi.name == element.name)) {
        wifiList.add(wifi);
      }
    } else if (bulletin is TcpSocketIpBulletin) {
      tcpIP = bulletin.getTcpIP() ?? "";
      notifyListeners();
    } else if (bulletin is FirmwareVersionBulletin) {
      version = bulletin.payload;

      String mac = "";
      if (bluetoothDevice != null) mac = bluetoothDevice!.id.toString();

      if (mac.isNotEmpty) {
        OfflineOTAService.saveDevice(mac, version ?? "0.0.0");
      }

      // Chỉ tự động check firmware từ BLE data stream
      // Khi kết nối WiFi/SOCKET, wifi_socket_mixin đã xử lý việc này rồi
      if (!hasAutoCheckedFirmware && connectStatus == ConnectStatus.BLE) {
        hasAutoCheckedFirmware = true;
        checkCurrentFirmware();
      }

      notifyListeners();
    }
    notifyListeners();
  }
}

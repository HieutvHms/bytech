import 'package:new_renitek/const/ble_const.dart';
import 'package:new_renitek/const/enum.dart';
import 'package:new_renitek/models/data_bulletin.dart';
import 'package:new_renitek/providers/mixins/app_provider_state.dart';
import 'package:new_renitek/root.dart';
import 'package:new_renitek/service/offline_ota_service.dart';
import 'package:new_renitek/utils/convert_data.dart';
import 'package:new_renitek/utils/get_command_byte.dart';
import 'package:new_renitek/utils/show_status.dart';

mixin DeviceControlMixin on AppProviderState {
  void controlMotor(ControlType controlType) async {
    try {
      if (connectStatus == ConnectStatus.BLE &&
          bluetoothCharacteristic != null) {
        final commandBytes = getCommandByte(controlType);
        ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
            value: commandBytes);
      } else if (connectStatus == ConnectStatus.SOCKET &&
          tcpIP == '192.168.1.1') {
        final commandBytes = getCommandByte(controlType);
        final ip = tcpIP;
        if (ip.isNotEmpty) {
          await OfflineOTAService.controlDeviceViaHttp(ip, commandBytes);
        } else {
          throw Exception("Unknown IP address for HTTP control");
        }
      } else {
        if (socketTCP != null) {
          socketService.controlDevice(socketTCP!, controlType);
        }
      }
    } catch (e) {
      if (globalKey.currentContext != null) {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: "Control device failure",
          succcess: false,
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

      if (!hasAutoCheckedFirmware) {
        hasAutoCheckedFirmware = true;
        checkCurrentFirmware();
      }

      notifyListeners();
    }
    notifyListeners();
  }
}

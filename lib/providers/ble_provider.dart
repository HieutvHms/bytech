// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/const/enum.dart';
import 'package:reintechnik/models/data_bulletin.dart';
import 'package:reintechnik/models/status_of_motor.dart';
import 'package:reintechnik/models/wifi.dart';
import 'package:reintechnik/service/ble_service.dart';
import 'package:reintechnik/utils/convert_data.dart';
import 'package:rxdart/rxdart.dart';

class BLEProvider extends ChangeNotifier {
  List<BluetoothDevice> bleDeviceList = [];
  BluetoothDevice? bluetoothDevice;
  List<Wifi> wifiList = [];
  BluetoothCharacteristic? bluetoothCharacteristic;
  final bleService = BLEService.instance;

  final bleStatusStream = BehaviorSubject<BLEStatus>();
  final motorStatus = BehaviorSubject<MotorStatus?>();
  final wifiStatusStream = BehaviorSubject<WifiStatus>();

  Future<void> scanDevice() async {
    bleStatusStream.add(BLEStatus.INITIAL);
    bleDeviceList = await BLEService.instance.startScanDevice();
    notifyListeners();
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      bluetoothDevice = device;
      bleStatusStream.add(BLEStatus.CONNECTED);
      discoveryService(device);
      device.state.listen((event) {
        if (event == BluetoothDeviceState.disconnected) {
          connectToDevice(device);
        }
      });
    } catch (e) {
      bleStatusStream.add(BLEStatus.ERROR);
    }
  }

  void discoveryService(BluetoothDevice device) async {
    try {
      bluetoothCharacteristic = await bleService.discoverService(device);
      listenDataFromBLE(bluetoothCharacteristic);
      notifyListeners();
    } catch (e) {
      bleStatusStream.add(BLEStatus.ERROR);
    }
  }

  void listenDataFromBLE(BluetoothCharacteristic? bluetoothCharacteristic) {
    bluetoothCharacteristic?.value.listen(
      (event) {
        final bulletin = getDataBulletin(event);
        if (bulletin is WifiStatusBulletin) {
        } else if (bulletin is MotorStatusBulletin) {
          final status = bulletin.getMotorStatus();
          motorStatus.add(status);
        } else if (bulletin is ScannedWifiListBulletin) {
          final wifi = bulletin.getWifiData();
          if (wifi.name.isEmpty) {
            wifiStatusStream.add(WifiStatus.STOP_SCAN);
          } else if (!wifiList.any((element) => wifi.name == element.name)) {
            wifiList.add(wifi);
          }
          notifyListeners();
        }
      },
    );
  }

  void controlMotor(ControlType controlType) {
    bleService.controlMotor(bluetoothCharacteristic!, controlType);
  }

  void scanWifi() {
    wifiStatusStream.add(WifiStatus.SCANNING);
    bleService.scanWifi(bluetoothCharacteristic!);
  }

  void confiWifi(Wifi wifi) {
    bleService.configWifiForDevice(bluetoothCharacteristic!, wifi);
  }
}

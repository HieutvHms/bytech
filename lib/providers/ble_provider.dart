// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/service/ble_service.dart';
import 'package:rxdart/rxdart.dart';

enum BLEStatus {
  INITIAL,
  CONNECTING,
  CONNECTED,
  DISCONNECTED,
  ERROR,
  ERROR_NO_DEVICES,
}

class BLEProvider extends ChangeNotifier {
  List<BluetoothDevice> bleDeviceList = [];
  BluetoothDevice? bluetoothDevice;
  BluetoothCharacteristic? bluetoothCharacteristic;

  final bleStatus = BehaviorSubject<BLEStatus>()..add(BLEStatus.INITIAL);

  void scanDevice() async {
    bleDeviceList = await BLEService.instance.startScanDevice();
    notifyListeners();
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      bluetoothDevice = device;
      device.state.listen((event) {
        if (event == BluetoothDeviceState.disconnected) {
          connectToDevice(device);
        }
      });
    } catch (e) {
      bleStatus.add(BLEStatus.ERROR);
    }
  }

  void discoveryService(BluetoothDevice device) async {
    bluetoothCharacteristic = await BLEService.instance.discoverService(device);
    notifyListeners();
  }
}

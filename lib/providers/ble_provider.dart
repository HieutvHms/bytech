// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/const/enum.dart';
import 'package:reintechnik/const/values.dart';
import 'package:reintechnik/models/status_of_motor.dart';
import 'package:reintechnik/service/ble_service.dart';
import 'package:rxdart/rxdart.dart';

class BLEProvider extends ChangeNotifier {
  List<BluetoothDevice> bleDeviceList = [];
  BluetoothDevice? bluetoothDevice;
  BluetoothCharacteristic? bluetoothCharacteristic;

  final bleStatusStream = BehaviorSubject<BLEStatus>();
  final motorStatus = BehaviorSubject<MotorStatus?>();
  void scanDevice() async {
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
      bluetoothCharacteristic =
          await BLEService.instance.discoverService(device);
      listenDataFromBLE(bluetoothCharacteristic);
      notifyListeners();
    } catch (e) {
      bleStatusStream.add(BLEStatus.ERROR);
    }
  }

  void listenDataFromBLE(BluetoothCharacteristic? bluetoothCharacteristic) {
    bluetoothCharacteristic?.value.listen(
      (event) {
        final status = _convertRawData(event);
        motorStatus.add(status);
      },
    );
  }
}

MotorStatus? _convertRawData(List<int> rawData) {
  final tranferData = String.fromCharCodes(rawData);
  final splitStringList = tranferData.split(":");
  final header = splitStringList[0];
  print(header);
  if (header == STATUS_HEADER) {
    final payload = splitStringList[1].substring(0, 4);

    final status = int.parse(payload.substring(0, 1));
    final postion = int.parse(payload.substring(1, 4));

    final motorStatus = MotorStatus(position: postion, status: status);
    return motorStatus;
  } else {
    return null;
  }
}

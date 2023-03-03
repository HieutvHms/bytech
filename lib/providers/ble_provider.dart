// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/const/enum.dart';
import 'package:reintechnik/models/status_of_motor.dart';
import 'package:reintechnik/service/ble_service.dart';
import 'package:reintechnik/utils/convert_data.dart';
import 'package:rxdart/rxdart.dart';

class BLEProvider extends ChangeNotifier {
  List<BluetoothDevice> bleDeviceList = [];
  BluetoothDevice? bluetoothDevice;

  BluetoothCharacteristic? bluetoothCharacteristic;
  final bleService = BLEService.instance;

  final bleStatusStream = BehaviorSubject<BLEStatus>();
  final motorStatus = BehaviorSubject<MotorStatus?>();

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
        final status = convertRawData(event);
        motorStatus.add(status);
      },
    );
  }

  void controlMotor(ControlType controlType) {
    bleService.controlMotor(bluetoothCharacteristic!, controlType);
  }

  void scanWifi() {
    bleService.scanWifi(bluetoothCharacteristic!);
  }
}

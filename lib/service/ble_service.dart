import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/const/values.dart';
import 'package:reintechnik/utils/get_command.dart';

//Packge BLE use : https://pub.dev/packages/flutter_blue_plus

class BLEService {
  BLEService._();

  static final BLEService instance = BLEService._();

  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;

  Future<List<BluetoothDevice>> startScanDevice() async {
    List<BluetoothDevice> scanDevices = [];
    await flutterBlue.startScan(
      timeout: const Duration(seconds: 4),
      allowDuplicates: false,
    );
    //Listen to scan result
    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!scanDevices.any((device) => device.name == r.device.name)) {
          scanDevices.add(r.device);
        }
      }
    });
    flutterBlue.stopScan();
    return scanDevices;
  }

  void connectToDevice(BluetoothDevice device) {
    device.connect();
    if (Platform.isAndroid) {
      device.requestMtu(96);
    }
  }

  Future<BluetoothCharacteristic?> discoverService(
      BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    try {
      final service = services
          .firstWhere((element) => element.uuid.toString() == SERVICE_UUID);

      await service.characteristics[1].setNotifyValue(true);

      return service.characteristics[1];
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  //Command Struct: Header + ID + Devider + Control Content+ Footer.
  void controlMotor(BluetoothCharacteristic c, ControlType controlType) {
    List<int> command = [];

    command.addAll(BLEConst.CONTROL_HEADER);
    command.addAll(BLEConst.CONTROL_ID);
    command.addAll(BLEConst.ID_PAYLOAD_DIVIVDER);
    command.addAll(controlType.getCommand());

    command.addAll(BLEConst.FOOTER);

    c.write(command);
  }
}

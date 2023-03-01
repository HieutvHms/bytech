import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/const/values.dart';

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
      device.requestMtu(512);
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
}

Uint8List int32bytes(int value) =>
    Uint8List(4)..buffer.asInt32List()[0] = value;

int bytesToInteger(List<int> bytes) {
  var value = 0;

  for (var i = 0, length = bytes.length; i < length; i++) {
    value += bytes[i] * pow(256, i).toInt();
  }

  return value;
}

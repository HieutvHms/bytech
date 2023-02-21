import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/const/values.dart';

//Packge BLE use : https://pub.dev/packages/flutter_blue_plus

class BLEService {
  BLEService._();
  static final BLEService instance = BLEService._();

  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;

  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  void startScanDevice() async {
    await flutterBlue.startScan(timeout: const Duration(seconds: 4));
    //Listen to scan result
    flutterBlue.scanResults.listen((result) {
      device = result
          .firstWhere((result) => result.device.name.contains("deivice name"))
          .device;
      //When find a device,connect and stop scan.
      if (device != null) {
        //Android need to request MTU size.
        //IOS always try to negotiate the highest possible MTU.
        if (Platform.isAndroid) {
          device!.requestMtu(512);
        }
        device!.connect();
        flutterBlue.stopScan();
        return;
      }
    });
    flutterBlue.stopScan();
  }

  void discoverService() async {
    List<BluetoothService> services = await device!.discoverServices();
    for (var service in services) {
      if (service.uuid.toString() == SERVICE_UUID) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == CHARACTICE_UUID) {
            characteristic = characteristic;
            return;
          }
        }
      }
    }
  }
}

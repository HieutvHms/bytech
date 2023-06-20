import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/const/values.dart';
import 'package:reintechnik/models/wifi.dart';
import 'package:reintechnik/utils/get_command_byte.dart';

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
          if (r.device.name.toLowerCase().contains("AVMOTOR".toLowerCase())) {
            scanDevices.add(r.device);
          }
        }
      }
    });
    flutterBlue.stopScan();
    return scanDevices;
  }

  Future<BluetoothCharacteristic?> discoverService(
      BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    try {
      final service = services
          .firstWhere((element) => element.uuid.toString() == SERVICE_UUID);

      await service.characteristics[1].setNotifyValue(true);
      if (Platform.isAndroid) {
        await device.requestMtu(96);
      }
      return service.characteristics[1];
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  //Command Struct: Header + ID + Devider + Control Content+ Footer.
  void controlMotor(BluetoothCharacteristic c, ControlType controlType) async {
    try {
      List<int> command = getCommandByte(controlType);
      await c.write(command);
    } catch (e) {
      controlMotor(c, controlType);
    }
  }

  void scanWifi(BluetoothCharacteristic c) {
    List<int> command = [];

    command.addAll(BLERequestConst.CONTROL_HEADER);
    command.addAll(BLERequestConst.SCAN_WIFI_ID);
    command.addAll(BLERequestConst.ID_PAYLOAD_DIVIVDER);
    command.addAll(BLERequestConst.FOOTER);
    print(command);

    c.write(command);
  }

//Config wifi struct : Header + ID + Devider + "-"+ SSID Len +
// SSID + "-" + Pass len+ "-"+ Pass + Footer
  void configWifiForDevice(BluetoothCharacteristic c, Wifi wifi) {
    List<int> command = [];
    command.addAll(BLERequestConst.CONTROL_HEADER);
    command.addAll(BLERequestConst.CONFIG_WIFI_ID);
    command.addAll(BLERequestConst.ID_PAYLOAD_DIVIVDER);
    //Name  length < 10 => 0+ Name .(EX: Name length =6 =>06)
    final nameLength = wifi.name.length < 10
        ? "0${wifi.name.length}"
        : wifi.name.length.toString();

    command.addAll(utf8.encode(nameLength));
    command.addAll(BLERequestConst.DASH);
    command.addAll(utf8.encode(wifi.name));
    command.addAll(BLERequestConst.DASH);
    //Pass  length < 10 => 0+ Pass .(EX: Pass length =6 =>06)
    final passLength = wifi.password!.length < 10
        ? "0${wifi.password!.length}"
        : wifi.password!.length.toString();
    command.addAll(utf8.encode(passLength));
    command.addAll(BLERequestConst.DASH);
    command.addAll(utf8.encode(wifi.password!));
    command.addAll(BLERequestConst.FOOTER);
    c.write(command);
  }
}

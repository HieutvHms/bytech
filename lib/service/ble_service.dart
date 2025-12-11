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

  // FlutterBluePlus flutterBlue = FlutterBluePlus.instance;

  Future<List<BluetoothDevice>> startScanDevice() async {
    List<BluetoothDevice> scanDevices = [];

    // Clear previous scan
    scanDevices.clear();

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 4),
    );

    // Listen for results during scanning
    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        print("========== BLE DEVICE FOUND ==========");
        print("remoteId      : ${r.device.remoteId}");
        print("device.name   : '${r.device.name}'");
        print("advName       : '${r.device.advName}'");
        print("RSSI          : ${r.rssi}");
        print("txPowerLevel  : ${r.advertisementData.txPowerLevel}");

        print("manufacturerData:");
        r.advertisementData.manufacturerData.forEach((k, v) {
          print("  ID: $k   DATA: ${v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");
        });

        print("serviceData:");
        r.advertisementData.serviceData.forEach((k, v) {
          print("  UUID: $k  DATA: ${v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");
        });

        print("serviceUuids: ${r.advertisementData.serviceUuids}");

        print("======================================");

        // Lọc thiết bị AVMOTOR
        if (!scanDevices.any((d) => d.remoteId == r.device.remoteId)) {
          if (r.device.advName.toLowerCase().contains("avmotor".toLowerCase())) {
            scanDevices.add(r.device);
          }
        }
      }
    });

    // Wait for scan to finish (timeout)
    await FlutterBluePlus.isScanning.where((s) => s == false).first;

    // Cancel listener to avoid memory leak
    await subscription.cancel();

    return scanDevices;
  }

  Future<BluetoothCharacteristic?> discoverService(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    try {
      final service = services.firstWhere((element) => element.uuid.toString() == SERVICE_UUID);

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
      rethrow;
    }
  }

  void updateFirmware(BluetoothCharacteristic c, String url) async {
    try {
      List<int> command = [];
      final endcode = utf8.encode("#5:$url!");
      command.addAll(endcode);
      await c.write(command);
    } catch (e) {
      rethrow;
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
    final nameLength = wifi.name.length < 10 ? "0${wifi.name.length}" : wifi.name.length.toString();

    command.addAll(utf8.encode(nameLength));
    command.addAll(BLERequestConst.DASH);
    command.addAll(utf8.encode(wifi.name));
    command.addAll(BLERequestConst.DASH);
    //Pass  length < 10 => 0+ Pass .(EX: Pass length =6 =>06)
    final passLength = wifi.password!.length < 10 ? "0${wifi.password!.length}" : wifi.password!.length.toString();
    command.addAll(utf8.encode(passLength));
    command.addAll(BLERequestConst.DASH);
    command.addAll(utf8.encode(wifi.password!));
    command.addAll(BLERequestConst.FOOTER);
    c.write(command);
  }
}

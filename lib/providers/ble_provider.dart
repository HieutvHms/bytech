// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/const/enum.dart';
import 'package:reintechnik/models/data_bulletin.dart';
import 'package:reintechnik/models/status_of_motor.dart';
import 'package:reintechnik/models/wifi.dart';
import 'package:reintechnik/models/wifi_status.dart';
import 'package:reintechnik/service/ble_service.dart';
import 'package:reintechnik/service/mdns_service.dart';
import 'package:reintechnik/utils/convert_data.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nsd/nsd.dart';

class BLEProvider extends ChangeNotifier {
  List<BluetoothDevice> bleDeviceList = [];
  BluetoothDevice? bluetoothDevice;
  List<Wifi> wifiList = [];
  List<Service> localService = [];
  BluetoothCharacteristic? bluetoothCharacteristic;

  final bleService = BLEService.instance;

  StreamSubscription<BluetoothDeviceState>? subscription;

  final bleStatusStream = BehaviorSubject<BLEStatus>();
  final motorStatus = BehaviorSubject<MotorStatus?>();
  final wifiStatusStream = BehaviorSubject<WifiStatus>();
  final wifiConnectStatusStream = BehaviorSubject<WifiConnectStatus>();
  final mdnsService = MdnsService();

  Future<void> scanDevice() async {
    bleStatusStream.add(BLEStatus.SCANNING);
    bleDeviceList = await BLEService.instance.startScanDevice();
    bleStatusStream.add(BLEStatus.INITIAL);
    notifyListeners();
  }

  void scanLocalDevice() {}

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      bluetoothDevice = device;
      bleStatusStream.add(BLEStatus.CONNECTED);
      discoveryService(device);
      //Listen to disconnect device ,and auto connect
      subscription = device.state.listen((event) {
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
          final wifiStatus = bulletin.getWifiStatus();
          wifiConnectStatusStream.add(wifiStatus!);
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

  void disconnectDevice() async {
    subscription?.cancel();
    await bluetoothDevice!.disconnect();
    bluetoothDevice = null;
    bleStatusStream.add(BLEStatus.INITIAL);
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

  void scanLocalService() async {
    try {
      localService = (await mdnsService.startDiscoveryMDNS()).services;
      notifyListeners();
    } catch (e) {
      print(e);
    }
  }
}

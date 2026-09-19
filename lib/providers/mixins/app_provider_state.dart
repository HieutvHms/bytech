import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:new_renitek/const/enum.dart';
import 'package:new_renitek/models/mdns_connected_model.dart';
import 'package:new_renitek/models/saved_device_model.dart';
import 'package:new_renitek/models/status_of_motor.dart';
import 'package:new_renitek/models/wifi.dart';
import 'package:new_renitek/models/wifi_status.dart';
import 'package:new_renitek/service/check_firmware_service.dart';
import 'package:new_renitek/service/mdns_service.dart';
import 'package:new_renitek/service/socket_service.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:rxdart/rxdart.dart';

enum ConnectStatus { BLE, SOCKET }

enum MDNSStatus {
  SCANING,
  DONE_SCAN,
  NO_CONNECT,
}

abstract class AppProviderState extends ChangeNotifier {
  List<DiscoveredDevice> bleDeviceList = [];
  DiscoveredDevice? bluetoothDevice;
  ConnectStatus? connectStatus;
  List<Wifi> wifiList = [];
  List<nsd.Service> localService = [];
  Socket? socketTCP;
  String? wifiApMac;
  String tcpIP = "";
  QualifiedCharacteristic? bluetoothCharacteristic;
  MdnsConnectedClient? mdnsConnectedClient;
  Map<String, dynamic> renameMap = {};
  List<SavedDeviceModel> saveDeviceList = [];
  bool hasAutoCheckedFirmware = false;

  bool isLatestFirmware = false;
  bool isExpertMode = false;

  StreamSubscription<ConnectionStateUpdate>? subscription;
  StreamSubscription<DiscoveredDevice>? scanSubscription;
  final FlutterReactiveBle ble = FlutterReactiveBle();

  final bleStatusStream = BehaviorSubject<BLEStatus>();
  final mdnsStatusStream = BehaviorSubject<MDNSStatus>();
  final motorStatus = BehaviorSubject<MotorStatus?>();
  WifiStatus wifiStatusStream = WifiStatus.INITIAL;
  final wifiConnectStatusStream = BehaviorSubject<WifiConnectStatus>();
  final mdnsService = MdnsService();
  final socketService = SocketService.instance;
  String? version = "Not found";
  
  String? get hardwareVersion {
    if (version == null || version == 'Not found' || !version!.contains('-')) {
      return null;
    }
    final parts = version!.split('-');
    if (parts.length >= 2) {
      final hw = '${parts[0]}_${parts[1]}';
      if (hw == 'AV01_NEW_HW' || hw == 'AV03_NEW_HW') {
        return hw;
      }
    }
    return null;
  }

  FirmwareCheckResult? firmwareCheckResult;

  // Cross-mixin dependencies
  void convertDataToStatus(List<int> event);
  void disconnectTCP();
  Future<void> disconnectBLE();
  Future<void> checkCurrentFirmware();
  void updateFirmWare({String? url, String? offlineFilePath});
}

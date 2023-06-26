// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/const/enum.dart';
import 'package:reintechnik/models/data_bulletin.dart';
import 'package:reintechnik/models/mdns_connected_model.dart';
import 'package:reintechnik/models/status_of_motor.dart';
import 'package:reintechnik/models/wifi.dart';
import 'package:reintechnik/models/wifi_status.dart';
import 'package:reintechnik/root.dart';
import 'package:reintechnik/service/ble_service.dart';
import 'package:reintechnik/service/mdns_service.dart';
import 'package:reintechnik/service/socket_service.dart';
import 'package:reintechnik/service/storage_service.dart';
import 'package:reintechnik/utils/connectivity_extention.dart';
import 'package:reintechnik/utils/convert_data.dart';
import 'package:reintechnik/utils/show_status.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nsd/nsd.dart';

enum ConnectStatus { BLE, SOCKET }

enum MDNSStatus {
  SCANING,
  DONE_SCAN,
  NO_CONNECT,
}

class AppProvider extends ChangeNotifier {
  List<BluetoothDevice> bleDeviceList = [];
  BluetoothDevice? bluetoothDevice;
  ConnectStatus? connectStatus;
  List<Wifi> wifiList = [];
  List<Service> localService = [];
  Socket? socketTCP;
  String tcpIP = "";
  BluetoothCharacteristic? bluetoothCharacteristic;
  MdnsConnectedClient? mdnsConnectedClient;
  final bleService = BLEService.instance;
  Map<String, dynamic> renameMap = {};

  StreamSubscription<BluetoothDeviceState>? subscription;

  final bleStatusStream = BehaviorSubject<BLEStatus>();
  final mdnsStatusStream = BehaviorSubject<MDNSStatus>();
  final motorStatus = BehaviorSubject<MotorStatus?>();
  final wifiStatusStream = BehaviorSubject<WifiStatus>();
  final wifiConnectStatusStream = BehaviorSubject<WifiConnectStatus>();
  final mdnsService = MdnsService();
  final socketService = SocketService.instance;

  Future<void> scanDevice() async {
    final isBluetoothOn = await FlutterBluePlus.instance.isOn;
    if (!isBluetoothOn) {
      bleStatusStream.add(BLEStatus.BLUE_TOOTH_IS_OFF);
      return;
    }
    bleStatusStream.add(BLEStatus.SCANNING);
    bleDeviceList = await BLEService.instance.startScanDevice();
    bleStatusStream.add(BLEStatus.INITIAL);
    notifyListeners();
  }

  Future<void> getSaveName() async {
    final result = await StorageService.getSaveName();
    if (result != null) {
      renameMap = result;
      notifyListeners();
    }
  }

  void saveDeviceName(String deviceName, String saveName) async {
    renameMap[deviceName] = saveName;
    StorageService.saveName(renameMap);
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await disconnectBLE();
      await device.connect();

      bluetoothDevice = device;
      bleStatusStream.add(BLEStatus.CONNECTED);
      connectStatus = ConnectStatus.BLE;
      notifyListeners();
      discoveryService(device);
      //Listen to disconnect device ,and auto connect
      subscription = device.state.listen((event) {
        if (event == BluetoothDeviceState.disconnected &&
            bleStatusStream.value != BLEStatus.INITIAL) {
          showStatus(
            buildContext: globalKey.currentContext!,
            message: "Device is disconnect",
            succcess: false,
          );
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
        convertDataToStatus(event);
      },
    );
  }

  Future<void> disconnectBLE() async {
    subscription?.cancel();
    await bluetoothDevice?.disconnect();
    bluetoothDevice = null;
    bleStatusStream.add(BLEStatus.INITIAL);
    notifyListeners();
  }

  void disconnectTCP() {
    socketTCP?.destroy();
    socketTCP = null;
    notifyListeners();
  }

  void controlMotor(ControlType controlType) {
    try {
      if (connectStatus == ConnectStatus.BLE) {
        bleService.controlMotor(bluetoothCharacteristic!, controlType);
      } else {
        socketService.controlDevice(socketTCP!, controlType);
      }
    } catch (e) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: "Control device failure",
        succcess: false,
      );
    }
  }

  void scanWifi() {
    wifiStatusStream.add(WifiStatus.SCANNING);
    bleService.scanWifi(bluetoothCharacteristic!);
  }

  void confiWifi(Wifi wifi) {
    bleService.configWifiForDevice(bluetoothCharacteristic!, wifi);
  }

  void scanLocalService() async {
    final isConnected = await isConnectedInternet();
    if (!isConnected) {
      mdnsStatusStream.add(MDNSStatus.NO_CONNECT);
      return;
    }
    try {
      //remove all old service

      localService = [];
      notifyListeners();
      mdnsStatusStream.add(MDNSStatus.SCANING);
      //Start scan new service
      final discovery = (await mdnsService.startDiscoveryMDNS());

      discovery.addServiceListener(
        (service, status) {
          if (status == ServiceStatus.found) {
            if (!localService.any((element) => element.host == service.host)) {
              localService.add(service);
            }
            notifyListeners();
          }
        },
      );
      mdnsStatusStream.add(MDNSStatus.DONE_SCAN);
    } catch (e) {
      mdnsStatusStream.add(MDNSStatus.DONE_SCAN);
    }
  }

  Future<void> connectSocket(
      BuildContext context, String ip, int port, String name) async {
    try {
      //Remove connect to BLE
      disconnectBLE();

      socketTCP = await socketService.connect(
        ip,
        port,
        convertDataToStatus,
      );
      mdnsConnectedClient =
          MdnsConnectedClient(name: name, host: ip, port: port);

      showStatus(
        buildContext: globalKey.currentContext!,
        message: "Connect success",
        succcess: true,
      );
      connectStatus = ConnectStatus.SOCKET;
      notifyListeners();
    } catch (e) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: "Connect failed",
        succcess: false,
      );
    }
  }

  void convertDataToStatus(List<int> event) {
    final bulletin = getDataBulletin(event);
    if (bulletin is WifiStatusBulletin) {
      final wifiStatus = bulletin.getWifiStatus();
      if (wifiStatus != null) {
        wifiConnectStatusStream.add(wifiStatus);
      }
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
    } else if (bulletin is TcpSocketIpBulletin) {
      tcpIP = bulletin.getTcpIP() ?? "";
      notifyListeners();
    }
    notifyListeners();
  }
}

// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:new_renitek/const/ble_const.dart';
import 'package:new_renitek/const/enum.dart';
import 'package:new_renitek/const/values.dart';
import 'package:new_renitek/models/data_bulletin.dart';
import 'package:new_renitek/models/mdns_connected_model.dart';
import 'package:new_renitek/models/saved_device_model.dart';
import 'package:new_renitek/models/status_of_motor.dart';
import 'package:new_renitek/models/wifi.dart';
import 'package:new_renitek/models/wifi_status.dart';
import 'package:new_renitek/root.dart';
import 'package:new_renitek/service/check_firmware_service.dart';
import 'package:new_renitek/service/mdns_service.dart';
import 'package:new_renitek/service/socket_service.dart';
import 'package:new_renitek/service/storage_service.dart';
import 'package:new_renitek/utils/connectivity_extention.dart';
import 'package:new_renitek/utils/convert_data.dart';
import 'package:new_renitek/utils/get_command_byte.dart';
import 'package:new_renitek/utils/show_status.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:rxdart/rxdart.dart';

enum ConnectStatus { BLE, SOCKET }

enum MDNSStatus {
  SCANING,
  DONE_SCAN,
  NO_CONNECT,
}

class AppProvider extends ChangeNotifier {
  List<DiscoveredDevice> bleDeviceList = [];
  DiscoveredDevice? bluetoothDevice;
  ConnectStatus? connectStatus;
  List<Wifi> wifiList = [];
  List<nsd.Service> localService = [];
  Socket? socketTCP;
  String tcpIP = "";
  QualifiedCharacteristic? bluetoothCharacteristic;
  MdnsConnectedClient? mdnsConnectedClient;
  Map<String, dynamic> renameMap = {};
  List<SavedDeviceModel> saveDeviceList = [];
  StreamSubscription<ConnectionStateUpdate>? subscription;
  StreamSubscription<DiscoveredDevice>? scanSubscription;
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  final bleStatusStream = BehaviorSubject<BLEStatus>();
  final mdnsStatusStream = BehaviorSubject<MDNSStatus>();
  final motorStatus = BehaviorSubject<MotorStatus?>();
  WifiStatus wifiStatusStream = WifiStatus.INITIAL;
  final wifiConnectStatusStream = BehaviorSubject<WifiConnectStatus>();
  final mdnsService = MdnsService();
  final socketService = SocketService.instance;
  String? version = "AVMotor 000";
  FirmwareCheckResult? firmwareCheckResult;
  Future<void> scanDevice() async {
    // Cancel previous scan if running
    scanSubscription?.cancel();

    final bluetoothState = await _ble.statusStream.first;
    final isBluetoothOn = bluetoothState == BleStatus.ready;
    if (!isBluetoothOn) {
      bleStatusStream.add(BLEStatus.BLUE_TOOTH_IS_OFF);
      return;
    }

    bleStatusStream.add(BLEStatus.SCANNING);
    bleDeviceList.clear();
    print('Starting scan, cleared device list');
    notifyListeners();

    // Start scanning
    print('Starting BLE scan...');
    scanSubscription = _ble.scanForDevices(
      withServices: [], // Scan for all devices
      scanMode: ScanMode.lowLatency,
    ).listen(
      (device) {
        // Add all devices (even without names) for debugging
        if (!bleDeviceList.any((d) => d.id == device.id)) {
          final deviceName =
              device.name.isNotEmpty ? device.name : 'Unknown Device';
          print('Found device: $deviceName (${device.id})');
          bleDeviceList.add(device);
          print('Device added, total devices: ${bleDeviceList.length}');
          notifyListeners();
        }
      },
      onError: (error) {
        print('Scan error: $error');
        bleStatusStream.add(BLEStatus.ERROR);
        notifyListeners();
      },
    );

    // Stop scan after 10 seconds
    Timer(const Duration(seconds: 10), () {
      scanSubscription?.cancel();
      bleStatusStream.add(BLEStatus.INITIAL);
      notifyListeners();
    });
  }

  Future<void> getSaveName() async {
    final result = await StorageService.getSaveName();
    if (result != null) {
      renameMap = result;
      print('Loaded renameMap: $renameMap');
      notifyListeners();
    } else {
      print('No saved renameMap found');
    }
  }

  void getSaveDevice() async {
    final result = await StorageService.getDeviceList();
    saveDeviceList = result;
    notifyListeners();
  }

  void saveDeviceName(String deviceName, String saveName) async {
    print('Saving device name: "$deviceName" -> "$saveName"');
    renameMap[deviceName] = saveName;
    print('Updated renameMap: $renameMap');
    StorageService.saveName(renameMap);
    notifyListeners();
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    try {
      version = 'AVMotor 000';
      saveDeviceList.addAll(
        bleDeviceList
            .where(
              (e) => !saveDeviceList
                  .any((element) => element.deviceName == e.name),
            )
            .map(
              (e) => SavedDeviceModel(
                deviceName: e.name,
                deviceType: DeviceType.BLE,
              ),
            ),
      );
      StorageService.saveDeviceList(saveDeviceList);
      if (bluetoothDevice != null) {
        bleDeviceList.add(bluetoothDevice!);
      }
      await disconnectBLE();

      // Connect using reactive_ble
      subscription =
          _ble.connectToDevice(id: device.id).listen((connectionState) {
        switch (connectionState.connectionState) {
          case DeviceConnectionState.connected:
            print('BLE Connected to device: ${device.id}');
            bluetoothDevice = device;
            bleStatusStream.add(BLEStatus.CONNECTED);
            connectStatus = ConnectStatus.BLE;
            notifyListeners();
            // Discover services after MTU negotiation
            Timer(const Duration(milliseconds: 500), () {
              discoveryService(device);
            });

            // Request MTU for better data transfer
            Timer(const Duration(milliseconds: 3000), () {
              _requestMtu(device.id);
            });

            // Auto check firmware after successful connection
            Timer(const Duration(seconds: 3), () {
              checkCurrentFirmware();
            });

            // Auto check firmware after successful connection
            // Timer(const Duration(seconds: 5), () {
            //   checkCurrentFirmware();
            // });
            break;
          case DeviceConnectionState.disconnected:
            print('BLE Disconnected from device: ${device.id}');
            bluetoothDevice = null;
            bluetoothCharacteristic = null;
            if (bleStatusStream.value != BLEStatus.INITIAL) {
              showStatus(
                buildContext: globalKey.currentContext!,
                message: "Device disconnected",
                succcess: false,
              );
              bleStatusStream.add(BLEStatus.INITIAL);
              // Don't auto-reconnect, let user decide
            }
            notifyListeners();
            break;
          case DeviceConnectionState.connecting:
            print('BLE Connecting to device: ${device.id}');
            showStatus(
              buildContext: globalKey.currentContext!,
              message: "Connecting to device...",
              succcess: true,
            );
            break;
          case DeviceConnectionState.disconnecting:
            print('BLE Disconnecting from device: ${device.id}');
            break;
        }
      });
    } catch (e) {
      bleStatusStream.add(BLEStatus.ERROR);
    }
  }

  void discoveryService(DiscoveredDevice device) async {
    try {
      print('Starting service discovery for device: ${device.id}');

      // Discover services first
      final services = await _ble.discoverServices(device.id);
      print('Discovered ${services.length} services');

      // Log all discovered services
      for (final service in services) {
        print('Service: ${service.serviceId}');
        for (final characteristic in service.characteristics) {
          print('  Characteristic: ${characteristic.characteristicId}');
        }
      }

      // Define the characteristic using reactive_ble format
      bluetoothCharacteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(SERVICE_UUID),
        characteristicId: Uuid.parse(
            '6e400003-b5a3-f393-e0a9-e50e24dcca9e'), // UART TX characteristic
        deviceId: device.id,
      );

      print('Setting up characteristic notifications...');
      // Subscribe to characteristic notifications
      listenDataFromBLE(bluetoothCharacteristic);

      // Send initial command to get device version
      Timer(const Duration(seconds: 1), () {
        _requestDeviceVersion();
      });

      notifyListeners();
    } catch (e) {
      print('Service discovery error: $e');
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'Service discovery failed: $e',
        succcess: false,
      );
      bleStatusStream.add(BLEStatus.ERROR);
    }
  }

  /// Request MTU (Maximum Transmission Unit) for better data transfer
  Future<void> _requestMtu(String deviceId) async {
    try {
      print('Requesting MTU for device: $deviceId');
      final mtu = await _ble.requestMtu(deviceId: deviceId, mtu: 96);
      print('MTU negotiated: $mtu bytes');
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'MTU negotiated: $mtu bytes',
        succcess: true,
      );
    } catch (e) {
      print('MTU request failed: $e');
      // MTU request failure is not critical, continue with default MTU
    }
  }

  /// Request device version after connection
  void _requestDeviceVersion() {
    if (bluetoothCharacteristic != null) {
      try {
        final versionCommand = getVersionRequestCommand();
        print('Requesting device version...');
        _ble.writeCharacteristicWithResponse(
          bluetoothCharacteristic!,
          value: versionCommand,
        );
      } catch (e) {
        print('Failed to request device version: $e');
      }
    }
  }

  /// Monitor connection quality via RSSI
  Future<void> checkConnectionQuality() async {
    if (bluetoothDevice == null) return;

    try {
      final rssi = await _ble.readRssi(bluetoothDevice!.id);
      print('RSSI: $rssi dBm');

      String qualityMessage;
      if (rssi >= -50) {
        qualityMessage = 'Excellent signal ($rssi dBm)';
      } else if (rssi >= -70) {
        qualityMessage = 'Good signal ($rssi dBm)';
      } else if (rssi >= -85) {
        qualityMessage = 'Fair signal ($rssi dBm)';
      } else {
        qualityMessage = 'Poor signal ($rssi dBm)';
      }

      showStatus(
        buildContext: globalKey.currentContext!,
        message: qualityMessage,
        succcess: rssi >= -85,
      );
    } catch (e) {
      print('Failed to read RSSI: $e');
    }
  }

  void listenDataFromBLE(QualifiedCharacteristic? bluetoothCharacteristic) {
    if (bluetoothCharacteristic != null) {
      _ble.subscribeToCharacteristic(bluetoothCharacteristic).listen(
        (event) {
          print('Received BLE data: ${event.length} bytes');
          convertDataToStatus(event);
        },
        onError: (error) {
          print('BLE subscription error: $error');
          showStatus(
            buildContext: globalKey.currentContext!,
            message: 'BLE communication error',
            succcess: false,
          );
        },
      );
    }
  }

  Future<void> disconnectBLE() async {
    version = 'AVMotor 000';
    wifiConnectStatusStream.add(WifiConnectStatus());
    subscription?.cancel();
    scanSubscription?.cancel();
    if (bluetoothDevice != null) {
      // No direct disconnect method for DiscoveredDevice, connection is handled by stream
    }
    bluetoothDevice = null;
    bluetoothCharacteristic = null;
    firmwareCheckResult = null; // Reset firmware check result
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
      if (connectStatus == ConnectStatus.BLE &&
          bluetoothCharacteristic != null) {
        // Use reactive_ble to write to characteristic
        final commandBytes = getCommandByte(controlType);
        _ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
            value: commandBytes);
      } else {
        socketService.controlDevice(socketTCP!, controlType);
      }

      // Log the motor control action
    } catch (e) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: "Control device failure",
        succcess: false,
      );
    }
  }

  void updateFirmWare() {
    // Check if firmware check was performed and update is available
    if (firmwareCheckResult == null) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'Please check for firmware updates first',
        succcess: false,
      );
      return;
    }

    if (firmwareCheckResult!.noUpdate) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'Firmware is already up to date',
        succcess: true,
      );
      return;
    }

    try {
      showStatus(
        buildContext: globalKey.currentContext!,
        message:
            'Starting firmware update to ${firmwareCheckResult!.latestVersion}...',
        succcess: true,
      );

      if (connectStatus == ConnectStatus.BLE &&
          bluetoothCharacteristic != null) {
        // Use reactive_ble for firmware update
        final updateCommand = getFirmwareUpdateCommand();
        _ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
            value: updateCommand);
      } else if (socketTCP != null) {
        socketService.updateFirmWare(
          socket: socketTCP!,
          url: firmwareCheckResult?.updateUrl,
        );
      } else {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: 'No device connection available for update',
          succcess: false,
        );
        return;
      }

      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'Firmware update command sent successfully',
        succcess: true,
      );
    } catch (e) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'Failed to update firmware: $e',
        succcess: false,
      );
    }
  }

  void scanWifi() {
    if (bluetoothCharacteristic != null) {
      wifiStatusStream = WifiStatus.SCANNING;
      final scanCommand = getScanWifiCommand();
      _ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
          value: scanCommand);
      notifyListeners();
    }
  }

  void confiWifi(Wifi wifi) {
    if (bluetoothCharacteristic != null) {
      final configCommand = getConfigWifiCommand(wifi);
      _ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
          value: configCommand);
    }
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
          if (status == nsd.ServiceStatus.found) {
            if (!saveDeviceList
                .any((element) => element.deviceName == service.name)) {
              saveDeviceList.add(SavedDeviceModel(
                  deviceName: service.name ?? "", deviceType: DeviceType.MDNS));
            }
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
        wifiStatusStream = WifiStatus.STOP_SCAN;
      } else if (!wifiList.any((element) => wifi.name == element.name)) {
        wifiList.add(wifi);
      }
    } else if (bulletin is TcpSocketIpBulletin) {
      tcpIP = bulletin.getTcpIP() ?? "";
      notifyListeners();
    } else if (bulletin is FirmwareVersionBulletin) {
      version = bulletin.payload;

      // Check firmware version and log
      _checkAndLogFirmware();

      notifyListeners();
    }
    notifyListeners();
  }

  // Logging and Firmware Check Methods

  /// Check firmware version and log the check
  void _checkAndLogFirmware() async {
    if (version == null) return;

    try {
      final deviceMac = _getCurrentDeviceMac();
      if (deviceMac.isEmpty) {
        print('Cannot check firmware: no device MAC address');
        return;
      }

      print('Firmware check result: Current $version');

      final firmwareResult = await CheckFirmwareService.checkFirmware(
        mac: deviceMac,
        currentVersion: version!,
      );

      if (firmwareResult != null) {
        if (!firmwareResult.noUpdate) {
          showStatus(
            buildContext: globalKey.currentContext!,
            message:
                'Firmware update available: ${firmwareResult.latestVersion}',
            succcess: true,
          );
          if (firmwareResult.updateUrl.isNotEmpty) {
            print('Update URL: ${firmwareResult.updateUrl}');
          }
        }
      }
    } catch (e) {
      print('Failed to check firmware: $e');
    }
  }

  /// Get current device MAC address for firmware checking
  String _getCurrentDeviceMac() {
    if (connectStatus == ConnectStatus.BLE && bluetoothDevice != null) {
      return bluetoothDevice!.id;
    } else if (connectStatus == ConnectStatus.SOCKET &&
        mdnsConnectedClient != null) {
      // For socket connections, use IP as identifier since MAC might not be available
      return mdnsConnectedClient!.host;
    }
    return '';
  }

  /// Manually trigger firmware check (for UI usage)
  Future<FirmwareCheckResult?> checkCurrentFirmware() async {
    if (version == null) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'No firmware version available',
        succcess: false,
      );
      return null;
    }

    final deviceMac = _getCurrentDeviceMac();
    if (deviceMac.isEmpty) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'Cannot check firmware: no device MAC address',
        succcess: false,
      );
      return null;
    }
    print("Checking firmware for device: $deviceMac, version: $version");
    try {
      final result = await CheckFirmwareService.checkFirmware(
        mac: deviceMac,
        currentVersion: version!,
      );

      if (result != null) {
        firmwareCheckResult = result;
        // Show firmware check result to user
        if (!result.noUpdate) {
          showStatus(
            buildContext: globalKey.currentContext!,
            message: 'Update available: ${result.latestVersion}',
            succcess: true,
          );
        } else {
          showStatus(
            buildContext: globalKey.currentContext!,
            message: 'Firmware is up to date: ${result.currentVersion}',
            succcess: true,
          );
        }

        // Log the manual firmware check
      }

      return result;
    } catch (e) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'Failed to check firmware',
        succcess: false,
      );
      return null;
    }
  }

  // Helper methods for BLE commands
  List<int> getFirmwareUpdateCommand() {
    // Create firmware update command
    List<int> command = [];
    command.addAll(BLERequestConst.CONTROL_HEADER);
    command.addAll([51]); // Firmware update ID
    command.addAll(BLERequestConst.ID_PAYLOAD_DIVIVDER);
    command.addAll(BLERequestConst.FOOTER);
    return command;
  }

  List<int> getScanWifiCommand() {
    // Create scan wifi command
    List<int> command = [];
    command.addAll(BLERequestConst.CONTROL_HEADER);
    command.addAll(BLERequestConst.SCAN_WIFI_ID);
    command.addAll(BLERequestConst.ID_PAYLOAD_DIVIVDER);
    command.addAll(BLERequestConst.FOOTER);
    return command;
  }

  List<int> getConfigWifiCommand(Wifi wifi) {
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
    return command;
  }

  List<int> getVersionRequestCommand() {
    // Create version request command
    List<int> command = [];
    command.addAll(BLERequestConst.CONTROL_HEADER);
    command.addAll([50]); // Version request ID (adjust as needed)
    command.addAll(BLERequestConst.ID_PAYLOAD_DIVIVDER);
    command.addAll(BLERequestConst.FOOTER);
    return command;
  }
}

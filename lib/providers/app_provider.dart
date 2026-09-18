// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:new_renitek/const/ble_const.dart';
import 'package:new_renitek/const/enum.dart';
import 'package:new_renitek/const/values.dart';
import 'package:new_renitek/models/data_bulletin.dart';
import 'package:new_renitek/models/mdns_connected_model.dart';
import 'package:new_renitek/models/saved_device_model.dart';
import 'package:new_renitek/models/status_of_motor.dart';
import 'package:new_renitek/models/wifi.dart';
import 'package:new_renitek/models/wifi_status.dart';
import 'package:new_renitek/new_screen/controller_screen/new_controller_screen.dart';
import 'package:new_renitek/root.dart';
import 'package:new_renitek/service/check_firmware_service.dart';
import 'package:new_renitek/service/offline_ota_service.dart';
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
  String? wifiApMac;
  String tcpIP = "";
  QualifiedCharacteristic? bluetoothCharacteristic;
  MdnsConnectedClient? mdnsConnectedClient;
  Map<String, dynamic> renameMap = {};
  List<SavedDeviceModel> saveDeviceList = [];
  bool _hasAutoCheckedFirmware = false; // Flag to prevent multiple auto-checks

  bool isLatestFirmware = false;
  //trạng thái Expert Mode
  bool isExpertMode = false;

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
      withServices: const [], // Scan for all devices
      scanMode: ScanMode.balanced,
    ).listen(
      (device) {
        // Add all devices (even without names) for debugging
        if (!bleDeviceList.any((d) => d.id == device.id)) {
          final deviceName =
              device.name.isNotEmpty ? device.name : 'Unknown Device';
          print('Found device: $deviceName (${device.id})');
          if (deviceName.contains('AV')) {
            bleDeviceList.add(device);
            print('Device added, total devices: ${bleDeviceList.length}');
            notifyListeners();
          }
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

    isLatestFirmware = await StorageService.getIsLatestFirmware();
    //  Load trạng thái Expert Mode từ bộ nhớ
    isExpertMode = await StorageService.getExpertMode();

    notifyListeners();
  }

  //  hàm bật/tắt Expert Mode
  void toggleExpertMode(bool value) {
    isExpertMode = value;
    StorageService.saveExpertMode(value);
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
      version = 'Not found';
      _hasAutoCheckedFirmware = false;
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

            // Auto check firmware will now be triggered dynamically
            // when the Firmware Version is successfully received in convertDataToStatus.

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
      // showStatus(
      //   buildContext: globalKey.currentContext!,
      //   message: 'MTU negotiated: $mtu bytes',
      //   succcess: true,
      // );
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
    version = 'Not found';
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

  void controlMotor(ControlType controlType) async {
    try {
      if (connectStatus == ConnectStatus.BLE &&
          bluetoothCharacteristic != null) {
        // Use reactive_ble to write to characteristic
        final commandBytes = getCommandByte(controlType);
        _ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
            value: commandBytes);
      } else if (connectStatus == ConnectStatus.SOCKET &&
          tcpIP == '192.168.1.1') {
        // Use HTTP POST for Offline AP mode
        final commandBytes = getCommandByte(controlType);
        final ip = tcpIP;
        if (ip.isNotEmpty) {
          await OfflineOTAService.controlDeviceViaHttp(ip, commandBytes);
        } else {
          throw Exception("Unknown IP address for HTTP control");
        }
      } else {
        // Use TCP Socket for LAN/Online mode
        if (socketTCP != null) {
          socketService.controlDevice(socketTCP!, controlType);
        }
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

  void updateFirmWare({String? url, String? offlineFilePath}) {
    // Check if firmware check was performed and update is available
    if (firmwareCheckResult == null && offlineFilePath == null && url == null) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'Please check for firmware updates first',
        succcess: false,
      );
      return;
    }

    // Nếu người dùng chọn file local (offlineFilePath != null) thì bỏ qua check noUpdate
    if (firmwareCheckResult != null &&
        firmwareCheckResult!.noUpdate &&
        offlineFilePath == null) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'Firmware is already up to date',
        succcess: true,
      );
      return;
    }

    try {
      // BLE: Gửi URL qua BLE characteristic
      if (connectStatus == ConnectStatus.BLE &&
          bluetoothCharacteristic != null &&
          url != null) {
        final updateCommand = getFirmwareUpdateCommand(url);
        _ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
            value: updateCommand);
        print(updateCommand);
        print(String.fromCharCodes(updateCommand));
        toggleExpertMode(false);
        notifyListeners();
        showStatus(
          buildContext: globalKey.currentContext!,
          message: 'Firmware update command sent via BLE.',
          succcess: true,
        );
        return;
      }

      // Wi-Fi (Online/Offline): Gửi file qua HTTP POST
      // Lấy IP của thiết bị
      final ip = mdnsConnectedClient?.host ?? tcpIP;
      if (ip.isEmpty) {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: 'Failed to update firmware: IP Address is unknown',
          succcess: false,
        );
        return;
      }

      // Hiển thị vòng xoay loading
      showDialog(
        context: globalKey.currentContext!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Đang gửi Firmware..."),
                ],
              ),
            ),
          );
        },
      );

      Future<void> doUpdate(String filePath) async {
        await OfflineOTAService.pushFirmwareViaHttp(ip, filePath);
      }

      Future<String> getFilePath() async {
        if (offlineFilePath != null) {
          // OFFLINE: Dùng file đã lưu sẵn trong máy
          return offlineFilePath;
        } else if (url != null) {
          // ONLINE: Tải file .bin từ URL về máy trước rồi push qua HTTP
          showStatus(
            buildContext: globalKey.currentContext!,
            message: 'Đang tải firmware từ server...',
            succcess: true,
          );
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception(
                'Không tải được file từ server: HTTP ${response.statusCode}');
          }
          final directory = await getApplicationDocumentsDirectory();
          // Lấy tên file gốc từ URL (VD: AV01_NEW_HW_12102025.bin)
          final fileName = Uri.parse(url).pathSegments.last;
          final permanentPath = '${directory.path}/fw_$fileName';
          final permanentFile = File(permanentPath);
          await permanentFile.writeAsBytes(response.bodyBytes);

          // Kích hoạt tính năng DYNAMIC HARDWARE SHARING (Lưu chéo)
          // Lưu file này vào Rổ cứu hộ của dòng máy này để dùng cho mạch khác Offline
          if (hardwareVersion != null) {
            await OfflineOTAService.saveDynamicHardwareMapping(
                hardwareVersion!, url, permanentPath);
          }

          return permanentPath;
        } else {
          throw Exception('Không có file hoặc URL để cập nhật');
        }
      }

      getFilePath().then((filePath) {
        return doUpdate(filePath);
      }).then((_) {
        Navigator.pop(globalKey.currentContext!); // Close loading dialog
        notifyListeners();

        showDialog(
          context: globalKey.currentContext!,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Cập nhật thành công'),
              content: const Text(
                  'Thiết bị đã nhận bản cập nhật và đang khởi động lại.\n\n'
                  'Vui lòng vào Cài đặt Wi-Fi của điện thoại để kết nối lại với mạng của thiết bị (nếu cần), sau đó quay lại màn hình Connect để tiếp tục sử dụng.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Đóng dialog
                    disconnectTCP(); // Ngắt kết nối cũ
                    // Pop toàn bộ màn hình về root (màn hình Connect)
                    final rootContext = globalKey.currentContext;
                    if (rootContext != null) {
                      Navigator.of(rootContext)
                          .popUntil((route) => route.isFirst);
                    }
                  },
                  child: const Text('Đã hiểu'),
                ),
              ],
            );
          },
        );
      }).catchError((e) {
        Navigator.pop(globalKey.currentContext!); // Close loading
        showStatus(
          buildContext: globalKey.currentContext!,
          message: 'Lỗi cập nhật firmware: $e',
          succcess: false,
        );
      });
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
      print(configCommand);
      print(String.fromCharCodes(configCommand));
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
      tcpIP = ip;

      socketTCP = await socketService.connect(
        ip,
        port,
        convertDataToStatus,
      );

      //  Gọi HTTP GET lấy thông tin mạch
      try {
        print('Đang gọi HTTP GET để lấy thông tin mạch...');
        // Endpoint HTTP của mạch ở chế độ Wi-Fi AP
        final response = await http
            .get(Uri.parse('http://$ip/status'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);

          if (jsonData['FW'] != null) {
            version = jsonData['FW'].toString();
          }
          if (jsonData['MAC'] != null) {
            String rawMac = jsonData['MAC'].toString();
            if (rawMac.contains('WIFI-')) {
              final parts = rawMac.split('WIFI-');
              if (parts.length > 1) {
                wifiApMac = parts[1].split(',')[0].trim();
              }
            } else {
              wifiApMac = rawMac.trim();
            }
          }

          print(
              'Lấy thông tin thành công: MAC=$wifiApMac, FW=$version, HW=$hardwareVersion');

          // Lưu vào bộ nhớ cục bộ để dùng cho Offline OTA
          if (wifiApMac != null && wifiApMac!.isNotEmpty) {
            OfflineOTAService.saveDevice(wifiApMac!, version ?? "0.0.0");
          }
        }
      } catch (e) {
        print('Lỗi khi gọi HTTP GET lấy thông tin mạch: $e');
      }

      // Gửi 1 lệnh STOP xuống Firmware để yêu cầu Firmware trả về trạng thái Motor hiện tại
      // print('Sending initial STOP command to fetch Motor Status...');
      // socketService.controlDevice(socketTCP!, ControlType.STOP);

      mdnsConnectedClient =
          MdnsConnectedClient(name: name, host: ip, port: port);

      showStatus(
        buildContext: globalKey.currentContext!,
        message: "Connect success",
        succcess: true,
      );
      connectStatus = ConnectStatus.SOCKET;

      if (!_hasAutoCheckedFirmware) {
        _hasAutoCheckedFirmware = true;
        checkCurrentFirmware();
      }

      notifyListeners();

      // Tự động kiểm tra phiên bản ngầm (Sẽ bật bảng thông báo nếu có bản Offline)
      Timer(const Duration(seconds: 2), () {
        checkCurrentFirmware();
      });
    } catch (e) {
      print('====================================');
      print('LỖI KẾT NỐI SOCKET TỚI WI-FI AP: $e');
      print('====================================');
      showStatus(
        buildContext: globalKey.currentContext!,
        message: "Connect failed: $e",
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

      // Determine MAC or empty string for AP
      String mac = "";
      if (bluetoothDevice != null) mac = bluetoothDevice!.id.toString();

      // Save device for background sync if we have a MAC
      if (mac.isNotEmpty) {
        OfflineOTAService.saveDevice(mac, version ?? "0.0.0");
      }

      if (!_hasAutoCheckedFirmware) {
        _hasAutoCheckedFirmware = true;
        checkCurrentFirmware();
      }

      notifyListeners();
    }
    notifyListeners();
  }

  // Logging and Firmware Check Methods

  /// Check firmware version and log the check
  // void _checkAndLogFirmware() async {
  //   if (version == null) return;

  //   try {
  //     final deviceMac = _getCurrentDeviceMac();
  //     if (deviceMac.isEmpty) {
  //       print('Cannot check firmware: no device MAC address');
  //       return;
  //     }

  //     print('Firmware check result: Current $version');

  //     final firmwareResult = await CheckFirmwareService.checkFirmware(
  //       mac: deviceMac,
  //       currentVersion: version!,
  //     );

  //     if (firmwareResult != null) {
  //       if (!firmwareResult.noUpdate) {
  //         showStatus(
  //           buildContext: globalKey.currentContext!,
  //           message:
  //               'Firmware update available: ${firmwareResult.latestVersion}',
  //           succcess: true,
  //         );
  //         if (firmwareResult.updateUrl.isNotEmpty) {
  //           print('Update URL: ${firmwareResult.updateUrl}');
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     print('Failed to check firmware: $e');
  //   }
  // }

  /// Get current device MAC address for firmware checking
  String _getCurrentDeviceMac() {
    if (connectStatus == ConnectStatus.BLE && bluetoothDevice != null) {
      return bluetoothDevice!.id;
    } else if (connectStatus == ConnectStatus.SOCKET &&
        mdnsConnectedClient != null) {
      // Trả về MAC lấy được từ HTTP GET. Nếu không lấy được, fallback về IP.
      if (wifiApMac != null && wifiApMac!.isNotEmpty) {
        return wifiApMac!;
      }
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
    print("Checking firmware for device: $deviceMac, version: $version");
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOnlineSuccess = false;

      // 1. ONLINE CHECK (Thử check online nếu điện thoại báo đang có mạng Wi-Fi/4G)
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        if (hardwareVersion == null) {
          // TRƯỜNG HỢP 2: Kết nối được nhưng không xác định được hardware
          // Gọi API (tạm thời Mock) để lấy danh sách tất cả FW
          final listFirmwares = await CheckFirmwareService.getAllFirmwares();
          _showFallbackFirmwareDialog(listFirmwares);
          return null;
        }

        if (deviceMac.isNotEmpty && !deviceMac.contains('.')) {
          final result = await CheckFirmwareService.checkFirmware(
            mac: deviceMac,
            currentVersion: version!,
          );

          if (result != null) {
            isOnlineSuccess = true;
            firmwareCheckResult = result;
            if (!result.noUpdate) {
              showFirmwareUpdateDialog(
                  globalKey.currentContext!, this, result.updateUrl);
            } else {
              showStatus(
                buildContext: globalKey.currentContext!,
                message: 'Firmware is up to date: ${result.currentVersion}',
                succcess: true,
              );
            }
            return result; // Kết thúc nếu check Online thành công
          }
        } else {
          // Bị thiếu MAC -> Dừng luôn không check được
          showStatus(
            buildContext: globalKey.currentContext!,
            message:
                'Không thể kiểm tra bản cập nhật: Thiếu địa chỉ MAC của mạch!',
            succcess: false,
          );
          return null;
        }
      }

      // 2. OFFLINE CHECK (Dùng làm Fallback nếu không có mạng thật sự, hoặc đang nối Wi-Fi AP không Internet)
      if (!isOnlineSuccess) {
        if (connectStatus == ConnectStatus.BLE) {
          showStatus(
            buildContext: globalKey.currentContext!,
            message:
                'Please connect to Internet to check for updates via Bluetooth.',
            succcess: false,
          );
          return null;
        }

        /* 
        // [TÍNH NĂNG CŨ] TẠM THỜI COMMENT LẠI
        // Vì tính năng tải FW mới lưu theo Hardware Version chứ không lưu theo MAC nữa.
        final offlineData = await OfflineOTAService.getReadyOfflineUpdate(
            deviceMac,
            currentVersion: version);
        if (offlineData != null) {
          if (offlineData['latestVersion'] == version) {
            showStatus(
              buildContext: globalKey.currentContext!,
              message: 'Firmware is already up to date ($version).',
              succcess: true,
            );
            return null;
          }
          showDialog(
            context: globalKey.currentContext!,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('Offline Firmware Update'),
                content: Text(
                    'A cached firmware version (${offlineData['latestVersion']}) is available. Update now?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Later')),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      updateFirmWare(
                          offlineFilePath: offlineData['localFilePath']);
                    },
                    child: const Text('Update via Wi-Fi AP'),
                  ),
                ],
              );
            },
          );
        } else 
        */
        if (hardwareVersion != null) {
          // KHÔNG TÌM THẤY MAC, NHƯNG LẠI BIẾT HARDWARE VERSION!
          // Thử check xem trong máy có tải sẵn file cứu hộ cho Hardware này chưa
          Map<String, String>? autoFallbackData =
              await OfflineOTAService.getFallbackOfflineFilePath(
                  hardwareVersion!);
          if (autoFallbackData != null) {
            String autoFallbackFile = autoFallbackData['localFilePath']!;
            String url = autoFallbackData['url']!;
            String fileName = Uri.parse(url).pathSegments.last;

            showDialog(
              context: globalKey.currentContext!,
              builder: (ctx) {
                return AlertDialog(
                  title: const Text('Cập Nhật Firmware Tự Động'),
                  content: Text(
                      'Tìm thấy bản cập nhật: $fileName lưu sẵn trong điện thoại. Bạn có muốn nạp không?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Bỏ qua')),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        updateFirmWare(offlineFilePath: autoFallbackFile);
                      },
                      child: const Text('Nạp Firmware'),
                    ),
                  ],
                );
              },
            );
          } else {
            // ĐÃ BIẾT HW nhưng KHÔNG CÓ FILE TẢI SẴN -> Báo lỗi luôn chứ không hiện danh sách cứu hộ nữa
            showStatus(
              buildContext: globalKey.currentContext!,
              message:
                  'Không có kết nối Internet và không tìm thấy bản cập nhật Offline cho dòng máy $hardwareVersion',
              succcess: false,
            );
          }
        } else {
          // KHÔNG XÁC ĐỊNH ĐƯỢC HW VÀ KHÔNG CÓ MAC -> Mới hiện Danh sách cứu hộ để User tự chọn
          _showNoInternetFallbackPrompt();
        }
      }

      return null;
    } catch (e) {
      showStatus(
        buildContext: globalKey.currentContext!,
        message: 'Failed to check firmware',
        succcess: false,
      );
      return null;
    }
  }

  void _showNoInternetFallbackPrompt() {
    showDialog(
      context: globalKey.currentContext!,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Lỗi kết nối mạng'),
          content: const Text(
              'Không có Internet để kiểm tra mạch này.\nBạn có muốn chọn bản cập nhật đã lưu sẵn trong máy không?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Hủy')),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final listFirmwares =
                    await CheckFirmwareService.getAllFirmwares();
                _showFallbackFirmwareDialog(listFirmwares);
              },
              child: const Text('Chọn Firmware Cứu Hộ'),
            ),
          ],
        );
      },
    );
  }

  // Helper methods for BLE commands
  List<int> getFirmwareUpdateCommand(String url) {
    // Create firmware update command
    List<int> command = [];
    command.addAll(utf8.encode('#5:$url!'));
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

  // Giao diện chọn Firmware khi không xác định được Hardware
  void _showFallbackFirmwareDialog(List<Map<String, dynamic>> listFirmwares) {
    if (globalKey.currentContext == null) return;
    showDialog(
      context: globalKey.currentContext!,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Chọn Firmware Cập Nhật'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: listFirmwares.length,
              itemBuilder: (context, index) {
                final fw = listFirmwares[index];
                return ListTile(
                  title: Text(fw['version'] ?? 'Unknown Version'),
                  subtitle: Text(fw['description'] ?? ''),
                  trailing: const Icon(Icons.download),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    if (fw['update_url'] != null) {
                      if (socketTCP != null) {
                        Map<String, String>? fallbackData =
                            await OfflineOTAService.getFallbackOfflineFilePath(
                                fw['version']);
                        if (fallbackData != null) {
                          String localFile = fallbackData['localFilePath']!;
                          updateFirmWare(offlineFilePath: localFile);
                          return;
                        }
                      }
                      updateFirmWare(url: fw['update_url']);
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
          ],
        );
      },
    );
  }
}

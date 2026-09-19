import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:new_renitek/const/enum.dart';
import 'package:new_renitek/const/values.dart';
import 'package:new_renitek/models/saved_device_model.dart';
import 'package:new_renitek/models/wifi_status.dart';
import 'package:new_renitek/providers/mixins/app_provider_state.dart';
import 'package:new_renitek/root.dart';
import 'package:new_renitek/service/storage_service.dart';
import 'package:new_renitek/utils/show_status.dart';
import 'package:new_renitek/utils/get_command_byte.dart';

mixin BleManagerMixin on AppProviderState {
  Future<void> scanDevice() async {
    scanSubscription?.cancel();

    final bluetoothState = await ble.statusStream.first;
    final isBluetoothOn = bluetoothState == BleStatus.ready;
    if (!isBluetoothOn) {
      bleStatusStream.add(BLEStatus.BLUE_TOOTH_IS_OFF);
      return;
    }

    bleStatusStream.add(BLEStatus.SCANNING);
    bleDeviceList.clear();

    notifyListeners();

    scanSubscription = ble.scanForDevices(
      withServices: const [],
      scanMode: ScanMode.balanced,
    ).listen(
      (device) {
        if (!bleDeviceList.any((d) => d.id == device.id)) {
          final deviceName =
              device.name.isNotEmpty ? device.name : 'Unknown Device';
          if (deviceName.contains('AV')) {
            bleDeviceList.add(device);
            notifyListeners();
          }
        }
      },
      onError: (error) {
        bleStatusStream.add(BLEStatus.ERROR);
        notifyListeners();
      },
    );

    Timer(const Duration(seconds: 10), () {
      scanSubscription?.cancel();
      bleStatusStream.add(BLEStatus.INITIAL);
      notifyListeners();
    });
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    try {
      version = 'Not found';
      hasAutoCheckedFirmware = false;
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

      subscription =
          ble.connectToDevice(id: device.id).listen((connectionState) {
        switch (connectionState.connectionState) {
          case DeviceConnectionState.connected:
            bluetoothDevice = device;
            bleStatusStream.add(BLEStatus.CONNECTED);
            connectStatus = ConnectStatus.BLE;
            notifyListeners();
            Timer(const Duration(milliseconds: 500), () {
              discoveryService(device);
            });

            Timer(const Duration(milliseconds: 3000), () {
              _requestMtu(device.id);
            });
            break;
          case DeviceConnectionState.disconnected:
            bluetoothDevice = null;
            bluetoothCharacteristic = null;
            if (bleStatusStream.value != BLEStatus.INITIAL) {
              if (globalKey.currentContext != null) {
                showStatus(
                  buildContext: globalKey.currentContext!,
                  message: "Device disconnected",
                  succcess: false,
                );
              }
              bleStatusStream.add(BLEStatus.INITIAL);
            }
            notifyListeners();
            break;
          case DeviceConnectionState.connecting:
            if (globalKey.currentContext != null) {
              showStatus(
                buildContext: globalKey.currentContext!,
                message: "Connecting to device...",
                succcess: true,
              );
            }
            break;
          case DeviceConnectionState.disconnecting:
            break;
        }
      });
    } catch (e) {
      bleStatusStream.add(BLEStatus.ERROR);
    }
  }

  void discoveryService(DiscoveredDevice device) async {
    try {
      final services = await ble.discoverServices(device.id);

      for (final service in services) {
        for (final characteristic in service.characteristics) {}
      }

      bluetoothCharacteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(SERVICE_UUID),
        characteristicId: Uuid.parse('6e400003-b5a3-f393-e0a9-e50e24dcca9e'),
        deviceId: device.id,
      );

      listenDataFromBLE(bluetoothCharacteristic);

      Timer(const Duration(seconds: 1), () {
        _requestDeviceVersion();
      });

      notifyListeners();
    } catch (e) {
      if (globalKey.currentContext != null) {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: 'Service discovery failed: $e',
          succcess: false,
        );
      }
      bleStatusStream.add(BLEStatus.ERROR);
    }
  }

  Future<void> _requestMtu(String deviceId) async {
    try {
      final mtu = await ble.requestMtu(deviceId: deviceId, mtu: 96);
    } catch (e) {}
  }

  void _requestDeviceVersion() {
    if (bluetoothCharacteristic != null) {
      try {
        final versionCommand = getVersionRequestCommand();
        ble.writeCharacteristicWithResponse(
          bluetoothCharacteristic!,
          value: versionCommand,
        );
      } catch (e) {}
    }
  }

  Future<void> checkConnectionQuality() async {
    if (bluetoothDevice == null) return;

    try {
      final rssi = await ble.readRssi(bluetoothDevice!.id);

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

      if (globalKey.currentContext != null) {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: qualityMessage,
          succcess: rssi >= -85,
        );
      }
    } catch (e) {}
  }

  void listenDataFromBLE(QualifiedCharacteristic? bluetoothCharacteristic) {
    if (bluetoothCharacteristic != null) {
      ble.subscribeToCharacteristic(bluetoothCharacteristic).listen(
        (event) {
          convertDataToStatus(event);
        },
        onError: (error) {
          if (globalKey.currentContext != null) {
            showStatus(
              buildContext: globalKey.currentContext!,
              message: 'BLE communication error',
              succcess: false,
            );
          }
        },
      );
    }
  }

  @override
  Future<void> disconnectBLE() async {
    version = 'Not found';
    wifiConnectStatusStream.add(WifiConnectStatus());
    subscription?.cancel();
    scanSubscription?.cancel();
    bluetoothDevice = null;
    bluetoothCharacteristic = null;
    firmwareCheckResult = null;
    notifyListeners();
  }
}

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleDeviceInteractor {
  BleDeviceInteractor({
    required Future<List<DiscoveredService>> Function(String deviceId)
        bleDiscoverServices,
    required void Function(String message) logMessage,
    required this.readRssi,
    required this.requestMtu,
  })  : _bleDiscoverServices = bleDiscoverServices,
        _logMessage = logMessage;

  final Future<List<DiscoveredService>> Function(String deviceId)
      _bleDiscoverServices;

  final Future<int> Function(String deviceId) readRssi;

  final Future<int> Function(String deviceId, int mtu) requestMtu;

  final void Function(String message) _logMessage;

  Future<List<DiscoveredService>> discoverServices(String deviceId) async {
    try {
      _logMessage('Start discovering services for: $deviceId');
      final result = await _bleDiscoverServices(deviceId);
      _logMessage(
          'Discovering services finished with ${result.length} services');

      // Log discovered services and characteristics
      for (final service in result) {
        _logMessage('Service: ${service.serviceId}');
        for (final characteristic in service.characteristics) {
          _logMessage('  Characteristic: ${characteristic.characteristicId}');
          _logMessage(
              '    Properties: ${characteristic.isReadable ? "R" : ""}${characteristic.isWritableWithResponse ? "W" : ""}${characteristic.isWritableWithoutResponse ? "w" : ""}${characteristic.isNotifiable ? "N" : ""}${characteristic.isIndicatable ? "I" : ""}');
        }
      }

      return result;
    } on Exception catch (e) {
      _logMessage('Error occurred when discovering services: $e');
      rethrow;
    }
  }

  Future<int> readConnectionRssi(String deviceId) async {
    try {
      _logMessage('Reading RSSI for: $deviceId');
      final result = await readRssi(deviceId);
      _logMessage('RSSI read: $result dBm');
      return result;
    } on Exception catch (e) {
      _logMessage('Error occurred when reading RSSI: $e');
      rethrow;
    }
  }

  Future<int> negotiateMtu(String deviceId, int requestedMtu) async {
    try {
      _logMessage('Requesting MTU $requestedMtu for: $deviceId');
      final result = await requestMtu(deviceId, requestedMtu);
      _logMessage('MTU negotiated: $result bytes');
      return result;
    } on Exception catch (e) {
      _logMessage('Error occurred when requesting MTU: $e');
      rethrow;
    }
  }
}

import 'logs_service.dart';

class CheckFirmwareService {
  /// Check firmware version using the firmware/check endpoint
  /// Expected response: {"mac": "AA:BB:CC:DD:EE", "version": "1.2.3", "update_url": "https://server/update/fw_1.2.3.bin"}
  /// Returns a FirmwareCheckResult with version comparison and update information
  static Future<FirmwareCheckResult?> checkFirmware({
    required String mac,
    required String currentVersion,
  }) async {
    try {
      final response = await LogsService.postFirmwareCheckWithResponse(
        mac: mac,
        version: currentVersion,
      );

      if (response != null) {
        // Validate expected response format
        if (response.containsKey('mac') &&
            response.containsKey('version') &&
            response.containsKey('update_url')) {
          final serverVersion = response['version'] as String;
          final updateUrl = response['update_url'] as String;
          final deviceMac = response['mac'] as String;
          final noUpdate = response['no_update'] as bool? ?? false;
          // Compare versions

          final result = FirmwareCheckResult(
            deviceMac: deviceMac,
            currentVersion: currentVersion,
            latestVersion: serverVersion,
            updateUrl: updateUrl,
            noUpdate: noUpdate,
          );

          print('Firmware check successful:');
          print('  Device MAC: ${result.deviceMac}');
          print('  Current version: ${result.currentVersion}');
          print('  Latest version: ${result.latestVersion}');
          print('  Update available: ${result.noUpdate}');
          if (!result.noUpdate) {
            print('  Update URL: ${result.updateUrl}');
          }

          return result;
        } else {
          print('Invalid firmware check response format: $response');
          return null;
        }
      } else {
        print('Firmware check successful (no response body)');
        return null;
      }
    } catch (e) {
      print('Failed to check firmware: $e');
      return null;
    }
  }
}

/// Result class for firmware check operations
class FirmwareCheckResult {
  final String deviceMac;
  final String currentVersion;
  final String latestVersion;
  final String updateUrl;
  final bool noUpdate;

  const FirmwareCheckResult({
    required this.deviceMac,
    required this.currentVersion,
    required this.latestVersion,
    required this.updateUrl,
    required this.noUpdate,
  });

  Map<String, dynamic> toJson() => {
        'device_mac': deviceMac,
        'current_version': currentVersion,
        'latest_version': latestVersion,
        'update_url': updateUrl,
        'no_update': noUpdate,
      };

  /// Simple firmware check with default version
  static Future<void> checkFirmwareSimple(String mac, String version) async {
    try {
      final response = await LogsService.postFirmwareCheck(
        mac: mac,
        version: version,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Firmware check request successful: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print('Response body: ${response.body}');
        }
      } else {
        print(
            'Firmware check request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Failed to send firmware check request: $e');
    }
  }
}

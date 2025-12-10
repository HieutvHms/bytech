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
          final isUpdateAvailable = !noUpdate;

          final result = FirmwareCheckResult(
            deviceMac: deviceMac,
            currentVersion: currentVersion,
            latestVersion: serverVersion,
            updateUrl: updateUrl,
            noUpdate: isUpdateAvailable,
          );

          print('Firmware check successful:');
          print('  Device MAC: ${result.deviceMac}');
          print('  Current version: ${result.currentVersion}');
          print('  Latest version: ${result.latestVersion}');
          print('  Update available: ${result.noUpdate}');
          if (result.noUpdate) {
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

  /// Compare version strings to determine if an update is available
  /// Returns true if serverVersion is newer than currentVersion
  static bool _isUpdateAvailable(String currentVersion, String serverVersion) {
    if (currentVersion == serverVersion) {
      return false;
    }

    // Handle "AVMotor" prefix versions
    final cleanCurrent = currentVersion.replaceFirst('AVMotor ', '').trim();
    final cleanServer = serverVersion.replaceFirst('AVMotor ', '').trim();

    try {
      // Simple version comparison for numeric versions
      final currentParts = cleanCurrent.split('.').map(int.parse).toList();
      final serverParts = cleanServer.split('.').map(int.parse).toList();

      // Pad shorter version with zeros
      final maxLength = currentParts.length > serverParts.length
          ? currentParts.length
          : serverParts.length;

      while (currentParts.length < maxLength) currentParts.add(0);
      while (serverParts.length < maxLength) serverParts.add(0);

      // Compare version parts
      for (int i = 0; i < maxLength; i++) {
        if (serverParts[i] > currentParts[i]) {
          return true;
        } else if (serverParts[i] < currentParts[i]) {
          return false;
        }
      }

      return false; // Versions are equal
    } catch (e) {
      // If numeric comparison fails, use string comparison
      return cleanServer.compareTo(cleanCurrent) > 0;
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

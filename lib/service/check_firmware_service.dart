import 'dart:convert';

import 'package:http/http.dart' as http;

class CheckFirmwareService {
  static const String baseUrl = 'http://42.96.40.74:8899';
  static const String logsEndpoint = '/logs';
  static const String firmwareCheckEndpoint = '/firmware/check';

  static Future<http.Response> postFirmwareCheck({
    required String mac,
    required String version,
  }) async {
    try {
      final Uri url = Uri.parse('$baseUrl$firmwareCheckEndpoint');

      final requestBody = {
        'mac': mac,
        'version': version,
      };

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      return response;
    } catch (e) {
      throw Exception('Failed to send firmware check request: $e');
    }
  }

  /// Send a POST request to the firmware check endpoint and parse the response
  static Future<Map<String, dynamic>?> postFirmwareCheckWithResponse({
    required String mac,
    required String version,
  }) async {
    try {
      final response = await postFirmwareCheck(mac: mac, version: version);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isNotEmpty) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        return null;
      } else {
        throw Exception('HTTP Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to process firmware check response: $e');
    }
  }

  static Future<FirmwareCheckResult?> checkFirmware({
    required String mac,
    required String currentVersion,
  }) async {
    try {
      final response = await postFirmwareCheckWithResponse(
        mac: mac,
        version: currentVersion,
      );

      if (response != null) {
        // Validate expected response format
        if (response.containsKey('mac') && response.containsKey('version') && response.containsKey('update_url')) {
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
      final maxLength = currentParts.length > serverParts.length ? currentParts.length : serverParts.length;

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
}

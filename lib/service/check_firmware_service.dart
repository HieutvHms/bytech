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
        if (response.containsKey('mac') && response.containsKey('version')) {
          final serverVersion = response['version'] as String;
          final updateUrl = (response['update_url'] as String?) ?? "";
          final deviceMac = response['mac'] as String;
          bool noUpdate = response['no_update'] as bool? ?? false;
          // Compare versions locally để tránh server báo ảo
          if (currentVersion.trim() == serverVersion.trim()) {
            noUpdate = true;
          }

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

  /// Gọi API lên server để lấy danh sách FW mới nhất cho tất cả dòng máy
  /// BE cần tạo endpoint: GET /api/firmware/latest
  /// Response mẫu:
  /// [
  ///   {"hardware": "AV01_NEW_HW", "version": "12172025", "url": "http://server/AV01_NEW_HW_12172025.bin"},
  ///   {"hardware": "AV02_NEW_HW", "version": "12172025", "url": "http://server/AV02_NEW_HW_12172025.bin"}
  /// ]
  static Future<List<Map<String, dynamic>>>
      getLatestFirmwaresFromServer() async {
    // Trả về 1 file có sẵn trên server để tải thành công và lưu vào DYNAMIC
    return [
      {"url": "http://27.71.226.192:2602/AV01_NEW_HW_12102025.bin"}
    ];

    /* Đoạn code gọi API thật tạm ẩn đi
    const String apiUrl = 'http://27.71.226.192:2602/api/firmware/latest';
    try {
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('getLatestFirmwaresFromServer: Lỗi gọi API, dùng fallback. Error: $e');
    }
    // Fallback: dùng danh sách cứng khi API chưa sẵn sàng
    return getAllFirmwares();
    */
  }

  static Future<List<Map<String, dynamic>>> getAllFirmwares() async {
    // Hard-coded list of firmwares provided by partner
    final Map<String, String> fallbackFirmwareMap = {
      "AV03-NEW_HW-002": "http://27.71.226.192:2602/AV03_NEW_HW_12102025.bin",
      "AV01-NEW_HW-002": "http://27.71.226.192:2602/AV01_NEW_HW_12102025.bin",
      "AV01-OLD_HW-001": "http://27.71.226.192:2602/AV01_OLD_HW_12102025.bin",
      "20250328-AV01-NL-PCBA-02_R01":
          "http://27.71.226.192:2602/AV01_OLD_HW_12102025.bin",
      "20250328-AV01-NL-PCBA-02_R02":
          "http://27.71.226.192:2602/AV01_OLD_HW_12172025_signed.bin",
      "AV03-OLD_HW_0_3":
          "http://27.71.226.192:2602/AV03-OLD_HW_0_3_12102025.bin",
    };

    return fallbackFirmwareMap.entries
        .map((e) => {
              "version": e.key,
              "update_url": e.value,
              "description": "Firmware ${e.key}",
            })
        .toList();
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

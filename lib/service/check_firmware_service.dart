import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;

import 'logs_service.dart';
import 'offline_ota_service.dart';

class CheckFirmwareService {
  static const String firmwareVersionsUrl =
      'https://rtv.devbt.com/firmware/versions';

  static Future<FirmwareCheckResult?> checkFirmware({
    required String mac,
    required String currentVersion,
  }) async {
    try {
      final response = await LogsService.postFirmwareCheckWithResponse(
        mac: mac,
        version: currentVersion,
      );

      print('Firmware Check Response: $response');

      if (response != null) {
        if (response.containsKey('mac') && response.containsKey('version')) {
          final serverVersion = response['version'] as String;
          final updateUrl = (response['update_url'] as String?) ?? "";
          final deviceMac = response['mac'] as String;
          bool noUpdate = response['no_update'] as bool? ?? false;
          // if (currentVersion.trim() == serverVersion.trim()) {
          //   noUpdate = true;
          // }

          final result = FirmwareCheckResult(
            deviceMac: deviceMac,
            currentVersion: currentVersion,
            latestVersion: serverVersion,
            updateUrl: updateUrl,
            noUpdate: noUpdate,
          );

          print('Firmware check successful (online):');
          print('  Device MAC: ${result.deviceMac}');
          print('  Current version: ${result.currentVersion}');
          print('  Latest version: ${result.latestVersion}');
          print('  Update available: ${!result.noUpdate}');
          if (!result.noUpdate) {
            print('  Update URL: ${result.updateUrl}');
          }

          return result;
        } else {
          print('Invalid firmware check response format: $response');
          return await _checkFirmwareOffline(mac, currentVersion);
        }
      } else {
        print('Firmware check: no response body, trying offline fallback');
        return await _checkFirmwareOffline(mac, currentVersion);
      }
    } catch (e) {
      print('Failed to check firmware: $e');
      // Không gọi được server (VD: đang ở WiFi AP riêng của thiết bị, không internet)
      // -> fallback dùng file .bin đã tải sẵn trong máy từ trước.
      return await _checkFirmwareOffline(mac, currentVersion);
    }
  }

  /// Fallback khi không có internet: tìm firmware .bin đã cache sẵn trong máy.
  static Future<FirmwareCheckResult?> _checkFirmwareOffline(
      String mac, String currentVersion) async {
    try {
      // Ưu tiên 1: firmware đã tải riêng cho đúng MAC này (qua syncFirmwareBackground).
      // final readyUpdate = await OfflineOTAService.getReadyOfflineUpdate(
      //   mac,
      //   currentVersion: currentVersion,
      // );
      // if (readyUpdate != null) {
      //   print('Offline OTA: Dùng firmware đã cache riêng cho MAC $mac');
      //   return FirmwareCheckResult(
      //     deviceMac: mac,
      //     currentVersion: currentVersion,
      //     latestVersion: readyUpdate['latestVersion'] as String,
      //     updateUrl: readyUpdate['localFilePath'] as String,
      //     noUpdate: false,
      //     isOffline: true,
      //   );
      // }

      // Ưu tiên 2: firmware tải theo dòng máy (nút "Tải FW Mới Nhất" /
      // "Kho Dự Phòng" ở màn Profile).
      final fallbackFile =
          await OfflineOTAService.getFallbackOfflineFilePath(currentVersion);
      if (fallbackFile != null) {
        print(
            'Offline OTA: Dùng firmware cache theo dòng máy cho $currentVersion');
        print(
            'Offline OTA: => File được chọn: ${fallbackFile['localFilePath']}');
        print('Offline OTA: => Version của file: ${fallbackFile['version']}');
        return FirmwareCheckResult(
          deviceMac: mac,
          currentVersion: currentVersion,
          latestVersion: fallbackFile['version'] ?? currentVersion,
          updateUrl: fallbackFile['localFilePath']!,
          noUpdate: false,
          isOffline: true,
        );
      }

      print(
          'Offline OTA: Không tìm thấy firmware cache nào cho $currentVersion — không thể check update khi offline.');
      return null;
    } catch (e) {
      print('Offline OTA: Fallback check thất bại: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getNewestFirmwares() async {
    final data = await _fetchFirmwareVersions();
    return _parseNewestFirmwares(data);
  }

  static Future<List<Map<String, dynamic>>> getBackupFirmwares() async {
    final data = await _fetchFirmwareVersions();
    return _parseBackupFirmwares(data);
  }

  static Future<int> downloadAndCacheFirmwares(bool useApi) async {
    final firmwares =
        useApi ? await getNewestFirmwares() : await getBackupFirmwares();

    if (firmwares.isEmpty) {
      return -1; // -1 means no firmware found
    }

    int successCount = 0;
    for (final fw in firmwares) {
      final url = fw['url'] ?? fw['update_url'] ?? '';
      if (url.isEmpty) continue;
      final fileName = Uri.parse(url).pathSegments.last;
      final hwType = (fw['hardware'] ?? fw['version'] ?? fileName)
          .toString()
          .replaceAll('.bin', '');
      final exactVersion = (fw['version'] ?? hwType).toString();

      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/$fileName';

      // Kiểm tra xem file đã tồn tại trong máy chưa
      if (await File(localPath).exists()) {
        await OfflineOTAService.saveDynamicHardwareMapping(
            hwType, exactVersion, url, localPath);
        successCount++;
        continue;
      }

      try {
        final res =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          await File(localPath).writeAsBytes(res.bodyBytes);
          await OfflineOTAService.saveDynamicHardwareMapping(
              hwType, exactVersion, url, localPath);
          successCount++;
        }
      } catch (e) {
        print('Lỗi tải $fileName: $e');
        // Tiếp tục thử tải file khác nếu có
      }
    }

    return successCount;
  }

  static Future<Map<String, dynamic>> _fetchFirmwareVersions() async {
    try {
      final response = await http
          .get(Uri.parse(firmwareVersionsUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP Error: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid firmware versions response');
      }
      return data;
    } catch (e) {
      print('getFirmwareVersions: Lỗi gọi API: $e');
      rethrow;
    }
  }

  static List<Map<String, dynamic>> _parseNewestFirmwares(
      Map<String, dynamic> data) {
    final versionsList = data['versions'];
    final result = <Map<String, dynamic>>[];

    if (versionsList is List) {
      for (final item in versionsList) {
        if (item is! Map) continue;
        final v = item['version']?.toString() ?? '';
        final url = _extractFirmwareUrl(item['update_url']?.toString() ?? '');
        if (v.isEmpty || url == null || url.isEmpty) continue;

        result.add({
          'version': v,
          'hardware': getFirmwareFamily(
              v), // vẫn giữ để hiển thị UI, không dùng để lọc nữa
          'update_url': url,
          'url': url,
          'is_newest': true,
          'description': 'Firmware $v (mới nhất)',
        });
      }
    }

    result.sort(
        (a, b) => (a['hardware'] as String).compareTo(b['hardware'] as String));
    return result;
  }

  static List<Map<String, dynamic>> _parseBackupFirmwares(
      Map<String, dynamic> data) {
    final firmwareDb = data['firmware_db'];
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};

    if (firmwareDb is Map) {
      firmwareDb.forEach((version, url) {
        final v = version.toString();
        final cleanUrl = _extractFirmwareUrl(url.toString());
        if (v.isEmpty || cleanUrl == null || cleanUrl.isEmpty) return;

        final key = '$v|$cleanUrl';
        if (!seen.add(key)) return;

        result.add({
          'version': v,
          'hardware': getFirmwareFamily(v),
          'update_url': cleanUrl,
          'url': cleanUrl,
          'is_newest': false,
          'description': 'Firmware $v (bản ổn định)',
        });
      });
    }

    result.sort(
        (a, b) => (a['version'] as String).compareTo(b['version'] as String));
    return result;
  }

  static String? _extractFirmwareUrl(String value) {
    final markdownMatch = RegExp(r'\]\((https?://[^)]+)\)').firstMatch(value);
    if (markdownMatch != null) return markdownMatch.group(1);
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return null;
  }

  /// tách family khác nhau (nguồn gốc của bug match sai key trước đó).
  static String getFirmwareFamily(String version) {
    final normalized = version
        .split('/')
        .last
        .replaceAll('.bin', '')
        .replaceAll('_signed', '');
    return normalized
        .replaceFirst(RegExp(r'_R\d+$'), '')
        .replaceFirst(RegExp(r'_\d{6,}$'), '')
        .replaceFirst(RegExp(r'-\d{3,}$'), '');
  }
}

class FirmwareCheckResult {
  final String deviceMac;
  final String currentVersion;
  final String latestVersion;
  final String updateUrl;
  final bool noUpdate;

  /// true nếu kết quả này lấy từ file .bin cache sẵn trong máy (offline),
  /// không phải từ server. Khi true, [updateUrl] là ĐƯỜNG DẪN FILE CỤC BỘ,
  /// KHÔNG PHẢI URL — nơi tiêu thụ (updateFirmWare) phải nạp thẳng file này,
  /// không được gọi http.get(updateUrl) nữa.
  final bool isOffline;

  const FirmwareCheckResult({
    required this.deviceMac,
    required this.currentVersion,
    required this.latestVersion,
    required this.updateUrl,
    required this.noUpdate,
    this.isOffline = false,
  });

  Map<String, dynamic> toJson() => {
        'device_mac': deviceMac,
        'current_version': currentVersion,
        'latest_version': latestVersion,
        'update_url': updateUrl,
        'no_update': noUpdate,
        'is_offline': isOffline,
      };

  // static Future<void> checkFirmwareSimple(String mac, String version) async {
  //   try {
  //     final response = await LogsService.postFirmwareCheck(
  //       mac: mac,
  //       version: version,
  //     );

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       print('Firmware check request successful: ${response.statusCode}');
  //       if (response.body.isNotEmpty) {
  //         print('Response body: ${response.body}');
  //       }
  //     } else {
  //       print(
  //           'Firmware check request failed: ${response.statusCode} - ${response.body}');
  //     }
  //   } catch (e) {
  //     print('Failed to send firmware check request: $e');
  //   }
  // }
}

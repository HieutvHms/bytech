import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:new_renitek/service/check_firmware_service.dart';

class OfflineOTAService {
  static const String otaDevicesKey = 'offline_ota_devices';
  static const String otaFallbackKey = 'offline_ota_fallback_devices';

  static Future<void> saveDevice(String mac, String currentVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(otaDevicesKey);
    List<dynamic> devices = data != null ? json.decode(data) : [];

    int index = devices.indexWhere((element) => element['mac'] == mac);
    if (index >= 0) {
      devices[index]['version'] = currentVersion;
    } else {
      devices.add({
        'mac': mac,
        'version': currentVersion,
        'localFilePath': null,
        'latestVersion': null,
      });
    }
    await prefs.setString(otaDevicesKey, json.encode(devices));

    // Trigger background sync
    syncFirmwareBackground();
  }

  // Đồng bộ firmware cho các thiết bị đã lưu
  static Future<void> syncFirmwareBackground() async {
    try {
      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        print('Offline OTA: No internet, skip background sync');
        return;
      }
    } catch (e) {
      print(
          'Offline OTA: Connectivity check failed, proceeding anyway. Error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(otaDevicesKey);
    if (data == null) return;

    List<dynamic> devices = json.decode(data);
    bool updated = false;

    for (var device in devices) {
      String mac = device['mac'];
      String currentVersion = device['version'];

      try {
        final result = await CheckFirmwareService.checkFirmware(
            mac: mac, currentVersion: currentVersion);
        if (result != null && !result.noUpdate && result.updateUrl.isNotEmpty) {
          if (device['latestVersion'] != result.latestVersion ||
              device['localFilePath'] == null) {
            print(
                'Offline OTA: Downloading firmware for $mac from ${result.updateUrl}');
            // Xóa file cũ để dọn dẹp rác bộ nhớ
            if (device['localFilePath'] != null) {
              try {
                final oldFile = File(device['localFilePath']);
                if (await oldFile.exists()) {
                  await oldFile.delete();
                  print('Offline OTA: Deleted old firmware file.');
                }
              } catch (e) {
                print('Offline OTA: Failed to delete old firmware file: $e');
              }
            }
            final directory = await getApplicationDocumentsDirectory();
            // Lấy tên file gốc từ URL (VD: AV01_NEW_HW_12102025.bin)
            final fileName = Uri.parse(result.updateUrl).pathSegments.last;
            final filePath = '${directory.path}/fw_$fileName';
            final file = File(filePath);

            if (await file.exists()) {
              print(
                  'Offline OTA: Firmware already downloaded for URL: ${result.updateUrl}');
              device['localFilePath'] = filePath;
              device['latestVersion'] = result.latestVersion;
              updated = true;
            } else {
              final response = await http.get(Uri.parse(result.updateUrl));
              if (response.statusCode == 200) {
                await file.writeAsBytes(response.bodyBytes);
                device['localFilePath'] = filePath;
                device['latestVersion'] = result.latestVersion;
                updated = true;
                print(
                    'Offline OTA: Firmware downloaded and saved to $filePath');
              }
            }
          }
        }
      } catch (e) {
        print('Offline OTA: Failed to process device $mac: $e');
      }
    }

    if (updated) {
      await prefs.setString(otaDevicesKey, json.encode(devices));
    }

    // 2. Download Fallback Firmwares
    try {
      final fallbacks = await CheckFirmwareService.getAllFirmwares();
      final fallbackDataStr = prefs.getString(otaFallbackKey);
      Map<String, dynamic> fallbackCache =
          fallbackDataStr != null ? json.decode(fallbackDataStr) : {};
      bool fallbackUpdated = false;

      for (var fw in fallbacks) {
        String version = fw['version'];
        String url = fw['update_url'];

        // Nếu URL này chưa được tải hoặc bị mất file
        bool needDownload = true;
        if (fallbackCache.containsKey(version)) {
          final cachedInfo = fallbackCache[version];
          if (cachedInfo['url'] == url) {
            final oldFile = File(cachedInfo['localFilePath']);
            if (await oldFile.exists()) {
              needDownload = false;
            }
          }
        }

        if (needDownload) {
          print(
              'Offline OTA: Downloading FALLBACK firmware $version from $url');
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final directory = await getApplicationDocumentsDirectory();
            final fileName = Uri.parse(url).pathSegments.last;
            final filePath = '${directory.path}/fw_fallback_$fileName';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);

            fallbackCache[version] = {
              'url': url,
              'localFilePath': filePath,
            };
            fallbackUpdated = true;
            print('Offline OTA: Fallback firmware downloaded to $filePath');
          }
        }
      }

      if (fallbackUpdated) {
        await prefs.setString(otaFallbackKey, json.encode(fallbackCache));
      }
    } catch (e) {
      print('Offline OTA: Failed to download fallback firmwares: $e');
    }
  }

  // Luu thông tin mới nhất từ server xuống điện thoại
  static Future<void> saveDynamicHardwareMapping(
      String hardwareVersion, String url, String localFilePath) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(otaFallbackKey);
    Map<String, dynamic> fallbackCache = data != null ? json.decode(data) : {};

    // Key cố định cho dòng máy
    String key = 'DYNAMIC_$hardwareVersion';

    // Nếu đã có file cũ xoá file cũ đi
    if (fallbackCache.containsKey(key)) {
      final oldPath = fallbackCache[key]['localFilePath'];
      // Cần check oldPath != localFilePath vì nếu tải lại cùng 1 file, file mới vừa tải xong sẽ bị xoá nhầm
      if (oldPath != null && oldPath != localFilePath) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          try {
            await oldFile.delete();
          } catch (e) {}
        }
      }
    }

    // Lưu thông tin file mới
    fallbackCache[key] = {
      'version': hardwareVersion,
      'url': url,
      'localFilePath': localFilePath,
    };

    await prefs.setString(otaFallbackKey, json.encode(fallbackCache));
  }

  /// Trích xuất số phiên bản cuối cùng trong chuỗi
  /// VD: "AV03_NEW_HW_12102025.bin" → 12102025
  ///     "AV03-NEW_HW-002"         → 2
  ///     "AV01-NEW_HW-003"         → 3
  static int extractVersionNumber(String s) {
    final clean = s.replaceAll('.bin', '');
    final matches = RegExp(r'\d+').allMatches(clean).toList();
    if (matches.isEmpty) return 0;
    return int.tryParse(matches.last.group(0)!) ?? 0;
  }

  static Future<Map<String, String>?> getFallbackOfflineFilePath(
      String version) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(otaFallbackKey);
    if (data == null) return null;

    Map<String, dynamic> fallbackCache = json.decode(data);

    // Chuẩn hóa chuỗi để so sánh
    String normalizedVersion =
        version.replaceAll('-', '').replaceAll('_', '').toUpperCase();
    // Trích xuất số phiên bản hiện tại của mạch
    int deviceVersionNum = extractVersionNumber(version);

    // Lọc ra tất cả các key khớp với hardwareVersion
    List<String> matchingKeys = [];
    for (var key in fallbackCache.keys) {
      String effectiveKey = key;

      if (key.startsWith('DYNAMIC_')) {
        effectiveKey = key.substring('DYNAMIC_'.length);
      } else {
        effectiveKey = key.replaceAll(RegExp(r'[-_]\d+$'), '');
      }

      String normalizedKey =
          effectiveKey.replaceAll('-', '').replaceAll('_', '').toUpperCase();
      // VD: "AV01NEWHW".contains trong "AV01NEWHW003" → MATCH
      if (normalizedKey.contains(normalizedVersion) ||
          normalizedVersion.contains(normalizedKey)) {
        matchingKeys.add(key);
      }
    }

    if (matchingKeys.isEmpty) return null;

    // Sắp xếp các key ưu tiên:
    // Những file có tiền tố DYNAMIC_ (được tải thực tế) xếp trên các file Code cứng
    matchingKeys.sort((a, b) {
      bool isADynamic = a.startsWith('DYNAMIC_');
      bool isBDynamic = b.startsWith('DYNAMIC_');

      if (isADynamic && !isBDynamic) return -1;
      if (!isADynamic && isBDynamic) return 1;
      return 0;
    });

    // Thử lấy file đầu tiên (mới nhất), kiểm tra version rồi mới trả về
    for (var key in matchingKeys) {
      final filePath = fallbackCache[key]['localFilePath'];
      final url = fallbackCache[key]['url'] ?? '';
      final file = File(filePath);
      if (!await file.exists()) continue;

      // SO SÁNH VERSION
      final fileName = Uri.parse(url).pathSegments.isNotEmpty
          ? Uri.parse(url).pathSegments.last
          : filePath.split('/').last;
      int fileVersionNum = extractVersionNumber(fileName);
      // Nếu khác version thì trả về để thực hiện update
      if (fileVersionNum != deviceVersionNum) {
        // File khác version (lớn hơn hoặc nhỏ hơn đều cho nạp) → hiện thông báo cập nhật!
        return {
          'localFilePath': filePath,
          'url': url,
        };
      } else {}
    }

    return null;
  }

  static Future<Map<String, dynamic>?> getReadyOfflineUpdate(String mac,
      {String? currentVersion}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(otaDevicesKey);
    if (data == null) return null;

    List<dynamic> devices = json.decode(data);

    // Find device by mac or by currentVersion
    int index = -1;
    if (mac.isNotEmpty) {
      index = devices.indexWhere((element) => element['mac'] == mac);
    } else if (currentVersion != null && currentVersion.isNotEmpty) {
      index =
          devices.indexWhere((element) => element['version'] == currentVersion);
    }

    if (index >= 0) {
      final device = devices[index];
      if (device['localFilePath'] != null && device['latestVersion'] != null) {
        final file = File(device['localFilePath']);
        if (await file.exists()) {
          return {
            'latestVersion': device['latestVersion'],
            'localFilePath': device['localFilePath'],
          };
        }
      }
    }
    return null;
  }

  // static Future<void> pushFirmwareViaSocket(
  //     Socket socket, String filePath) async {
  //   try {
  //     final file = File(filePath);
  //     if (!await file.exists()) {
  //       throw Exception("Firmware file not found at $filePath");
  //     }

  //     print('Offline OTA: Pushing firmware via Socket from $filePath');

  //     // IMPORTANT: The firmware must be updated to handle this raw binary stream!
  //     // Currently, we just stream the file chunks.
  //     final bytes = await file.readAsBytes();

  //     int chunkSize = 1024; // Send 1KB at a time
  //     for (int i = 0; i < bytes.length; i += chunkSize) {
  //       int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
  //       socket.add(bytes.sublist(i, end));
  //       await Future.delayed(const Duration(
  //           milliseconds: 20)); // Delay to prevent buffer overflow
  //     }

  //     print('Offline OTA: Push completed.');
  //   } catch (e) {
  //     print('Offline OTA: Failed to push firmware via Socket: $e');
  //     rethrow;
  //   }
  // }

  static Future<void> pushFirmwareViaHttp(String ip, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception("Firmware file not found at $filePath");
      }

      print(
          'Offline OTA: Pushing firmware via HTTP POST to http://$ip/update-firmware');

      final url = Uri.parse('http://$ip/update-firmware');

      // Đọc toàn bộ file nhị phân
      final bytes = await file.readAsBytes();

      // Giống hệt code Web UI (xhr.setRequestHeader('Content-Type', 'application/octet-stream'))
      var response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/octet-stream',
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final respStr = response.body;
        print(
            'Offline OTA: Push HTTP completed successfully. FW Response: $respStr');
      } else {
        throw Exception("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      // Khi Firmware update thành công, nó thường sẽ lập tức Reset (khởi động lại)
      // Việc khởi động lại đột ngột sẽ ngắt kết nối HTTP khiến App văng lỗi SocketException / ClientException
      // Do đó, nếu gặp lỗi ngắt kết nối đột ngột, ta có thể ngầm hiểu là Mạch đã nạp thành công và đang Reset!
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('connection abort') ||
          errorStr.contains('connection reset') ||
          errorStr.contains('socketexception')) {
        print(
            'Offline OTA: Mạch ngắt kết nối đột ngột (Khả năng cao là update thành công và đang Reboot). Bỏ qua lỗi!');
        return; // Coi như thành công
      }

      print('Offline OTA: Failed to push firmware via HTTP: $e');
      rethrow;
    }
  }

  static Future<void> controlDeviceViaHttp(
      String ip, List<int> commandBytes) async {
    try {
      final url = Uri.parse('http://$ip/control');

      print('HTTP Control: Sending POST request to $url');
      var response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/octet-stream',
            },
            body: commandBytes,
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        throw Exception("HTTP Error: ${response.statusCode}");
      }
      print('HTTP Control: Success, Response: ${response.body}');
    } catch (e) {
      print('HTTP Control: Failed to send command: $e');
      rethrow;
    }
  }
}

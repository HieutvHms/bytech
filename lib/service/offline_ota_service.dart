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
        return;
      }
    } catch (e) {}

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
            if (device['localFilePath'] != null) {
              try {
                final oldFile = File(device['localFilePath']);
                if (await oldFile.exists()) {
                  await oldFile.delete();
                }
              } catch (e) {}
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
      final fallbacks = await CheckFirmwareService.getBackupFirmwares();
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
              'version': version,
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
  // --- Thay toàn bộ hàm saveDynamicHardwareMapping ---
  static Future<void> saveDynamicHardwareMapping(String hardwareFamily,
      String exactVersion, String url, String localFilePath) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(otaFallbackKey);
    Map<String, dynamic> fallbackCache = data != null ? json.decode(data) : {};

    String key = 'DYNAMIC_$hardwareFamily';

    if (fallbackCache.containsKey(key)) {
      final oldPath = fallbackCache[key]['localFilePath'];
      if (oldPath != null && oldPath != localFilePath) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          try {
            await oldFile.delete();
          } catch (e) {}
        }
      }
    }

    fallbackCache[key] = {
      'version': exactVersion, // SỬA: lưu version THẬT (vd "AV03-NEW_HW-002"),
      // không phải family nữa, để so sánh version đúng
      'family': hardwareFamily,
      'url': url,
      'localFilePath': localFilePath,
    };

    await prefs.setString(otaFallbackKey, json.encode(fallbackCache));
  }

  /// Trích xuất số phiên bản cuối cùng trong chuỗi
  /// VD: "AV03_NEW_HW_12102025.bin" → 12102025
  static double extractVersionNumber(String s) {
    try {
      final clean = s.replaceAll('.bin', '').trim();
      final parts = clean.split(RegExp(r'[-_]'));
      if (parts.isEmpty) return 0.0;
      final lastPart = parts.last;
      return double.tryParse(lastPart) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  static Future<Map<String, String>?> getFallbackOfflineFilePath(
      String version) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(otaFallbackKey);
    if (data == null) return null;

    Map<String, dynamic> fallbackCache = json.decode(data);

    // Loại bỏ số đuôi (VD: AV01-NEW_HW-004.1 -> AV01-NEW_HW) trước khi chuẩn hóa
    String effectiveVersion =
        version.replaceAll(RegExp(r'[-_]\d+(\.\d+)*$'), '');
    String normalizedVersion =
        effectiveVersion.replaceAll('-', '').replaceAll('_', '').toUpperCase();
    // Trích xuất số phiên bản hiện tại của mạch
    double deviceVersionNum = extractVersionNumber(version);

    List<String> matchingKeys = [];
    for (var key in fallbackCache.keys) {
      String effectiveKey = key;

      if (key.startsWith('DYNAMIC_')) {
        // DYNAMIC key: "DYNAMIC_AV01_NEW_HW"
        // → bỏ "DYNAMIC_" đầu → lấy "AV01_NEW_HW"
        effectiveKey = key.substring('DYNAMIC_'.length);
      } else {
        // Hardcoded key: "AV01-NEW_HW-002" hoặc "AV03-OLD_HW_0_3"
        // → bỏ đoạn cuối từ dấu '-' hoặc '_' kèm số
        effectiveKey = key.replaceAll(RegExp(r'[-_]\d+(\.\d+)*$'), '');
      }

      // Chuẩn hóa: xóa hết - và _ rồi so sánh
      String normalizedKey =
          effectiveKey.replaceAll('-', '').replaceAll('_', '').toUpperCase();

      if (normalizedKey == normalizedVersion) {
        matchingKeys.add(key);
      }
    }

    if (matchingKeys.isEmpty) return null;

    matchingKeys.sort((a, b) {
      bool isADynamic = a.startsWith('DYNAMIC_');
      bool isBDynamic = b.startsWith('DYNAMIC_');
      if (isADynamic && !isBDynamic) return -1;
      if (!isADynamic && isBDynamic) return 1;
      return 0;
    });

    for (var key in matchingKeys) {
      final entry = fallbackCache[key];
      final filePath = entry['localFilePath'];
      final url = entry['url'] ?? '';
      final savedVersion = entry['version']?.toString() ?? '';
      final file = File(filePath);
      if (!await file.exists()) continue;

      double fileVersionNum = extractVersionNumber(savedVersion);

      print(
          'Offline OTA: Device version string="$version" -> num=$deviceVersionNum, File version num=$fileVersionNum (from $savedVersion)');

      // Nếu phiên bản file lớn hơn phiên bản hiện tại thì trả về để update
      if (savedVersion.isNotEmpty && fileVersionNum > deviceVersionNum) {
        print(
            'Offline OTA: Found newer version! File ($fileVersionNum) > Device ($deviceVersionNum). Key: $key');
        return {
          'localFilePath': filePath,
          'url': url,
          'version': savedVersion, // TRẢ VỀ VERSION THẬT
        };
      } else {
        print(
            'Offline OTA: File version ($fileVersionNum) <= Device ($deviceVersionNum). No update needed.');
      }
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

  static Future<void> pushFirmwareViaHttp(
      String ip, String filePath, String expectedVersion) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("Firmware file not found at $filePath");
    }

    print(
        'Offline OTA: Pushing firmware [ $filePath ] via HTTP POST to http://$ip/update-firmware');

    final url = Uri.parse('http://$ip/update-firmware');
    final bytes = await file.readAsBytes();

    // KIỂM TRA FILE TRƯỚC KHI GỬI
    print('Offline OTA: File size = ${bytes.length} bytes');
    if (bytes.isNotEmpty) {
      final magicByte = bytes[0].toRadixString(16).toUpperCase();
      print('Offline OTA: Magic Byte = 0x$magicByte');
      if (bytes[0] != 0xE9) {
        print(
            "CẢNH BÁO: File nhị phân có Magic Byte 0x$magicByte khác 0xE9 (ESP32 chuẩn). Có thể là do header tùy chỉnh (vd: AV03_BYT). Vẫn tiếp tục đẩy file...");
      }
    }
    bool isPushingComplete = false; // Thêm cờ đánh dấu

    try {
      final request = http.StreamedRequest('POST', url);
      request.contentLength = bytes.length;
      request.headers['Connection'] = 'close';
      request.headers['Content-Type'] = 'application/octet-stream';

      final client = http.Client();
      final responseFuture =
          client.send(request).timeout(const Duration(seconds: 120));

      print(
          'Offline OTA: Sent headers. Waiting 2s for ESP32 to erase flash...');
      await Future.delayed(const Duration(seconds: 2));

      print('Offline OTA: Start pushing body chunks...');
      try {
        int chunkSize = 4096;
        for (int i = 0; i < bytes.length; i += chunkSize) {
          int end =
              (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
          request.sink.add(bytes.sublist(i, end));
          await Future.delayed(const Duration(milliseconds: 20));
        }
      } finally {
        request.sink.close();
      }

      // ĐÁNH DẤU LÀ ĐÃ GỬI XONG TOÀN BỘ BYTES
      isPushingComplete = true;

      print('Offline OTA: All bytes sent. Waiting for response...');
      var streamedResponse = await responseFuture;
      var response = await http.Response.fromStream(streamedResponse);
      client.close();

      if (response.statusCode == 200) {
        print('Offline OTA: Push HTTP completed successfully (HTTP 200).');
      } else {
        throw Exception("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      print('Offline OTA: Chi tiết lỗi khi push: $e');

      // CHỈ BỎ QUA LỖI RỚT MẠNG KHI VÀ CHỈ KHI ĐÃ GỬI XONG FILE
      if (isPushingComplete &&
          (errorStr.contains('connection abort') ||
              errorStr.contains('connection reset') ||
              errorStr.contains('socket closed') ||
              errorStr.contains('software caused connection abort') ||
              errorStr.contains('clientexception'))) {
        print(
            'Offline OTA: Mất kết nối khi push (mạch đang reboot). Đã đẩy file thành công!');
        return; // Thoát ra và báo thành công
      }

      // Còn nếu lỗi xảy ra lúc chưa gửi xong (ví dụ mất sóng, ko tìm thấy IP) thì văng lỗi thật
      rethrow;
    }
  }

  static Future<void> controlDeviceViaHttp(
      String ip, List<int> commandBytes) async {
    try {
      final url = Uri.parse('http://$ip/control');

      // Chuyển mảng byte (ví dụ: [35, 48, 58, 49, 49, 33]) thành chuỗi "#0:11!"
      final commandString = utf8.decode(commandBytes);

      // Đóng gói thành định dạng JSON mà Firmware đang yêu cầu: {"cmd":"#0:11!"}
      final bodyMap = {"cmd": commandString};

      final String jsonBody = jsonEncode(bodyMap);
      final List<int> bodyBytes = utf8.encode(jsonBody);

      print('HTTP Control: Sending POST request to $url with body: $jsonBody');

      var response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Content-Length': bodyBytes.length.toString(),
              'Connection': 'close',
            },
            body:
                bodyBytes, // Gửi raw bytes để tránh Dart tự thêm charset=utf-8 vào header
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

  /// Lấy danh sách firmware đã tải sẵn trong máy (đọc cache, KHÔNG gọi mạng).
  /// Dùng khi HW không xác định VÀ không có Internet — để vẫn cho người dùng
  /// chọn 1 trong các bản đã tải trước đó (qua nút Profile hoặc sync nền).
  static Future<List<Map<String, dynamic>>> getCachedBackupFirmwares() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(otaFallbackKey);
    if (data == null) return [];

    final Map<String, dynamic> fallbackCache = json.decode(data);
    final result = <Map<String, dynamic>>[];

    for (final entry in fallbackCache.entries) {
      final value = entry.value;
      final localFilePath = value['localFilePath'];
      if (localFilePath == null) continue;

      final file = File(localFilePath);
      if (!await file.exists())
        continue; // file đã bị xoá thì bỏ qua, tránh cho chọn bản không còn tồn tại

      final url = value['url']?.toString() ?? '';
      final key = entry.key;
      final family =
          key.startsWith('DYNAMIC_') ? key.substring('DYNAMIC_'.length) : key;
      final version = value['version']?.toString() ?? family;

      result.add({
        'version': version,
        'update_url': url,
        'url': url,
        'hardware': family,
        'is_newest': false,
        'description': 'Firmware $version (đã lưu trong máy)',
      });
    }

    result.sort(
        (a, b) => (a['version'] as String).compareTo(b['version'] as String));
    return result;
  }
}

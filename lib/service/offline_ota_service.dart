import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:new_renitek/service/check_firmware_service.dart';

class OfflineOTAService {
  static const String otaDevicesKey = 'offline_ota_devices';

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
            final response = await http.get(Uri.parse(result.updateUrl));
            if (response.statusCode == 200) {
              final directory = await getApplicationDocumentsDirectory();
              final filePath =
                  '${directory.path}/fw_${mac.replaceAll(':', '')}_${result.latestVersion}.bin';
              final file = File(filePath);
              await file.writeAsBytes(response.bodyBytes);

              device['localFilePath'] = filePath;
              device['latestVersion'] = result.latestVersion;
              updated = true;
              print('Offline OTA: Firmware downloaded and saved to $filePath');
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
}

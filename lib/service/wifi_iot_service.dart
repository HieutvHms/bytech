import 'dart:io';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WifiIotService {
  static Future<bool> requestLocationPermission() async {
    if (Platform.isIOS) return false;
    final status = await Permission.locationWhenInUse.request();
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  static Future<bool> checkIfWifiEnabled() async {
    if (Platform.isIOS) return true;
    try {
      return await WiFiForIoTPlugin.isEnabled();
    } catch (e) {
      return false;
    }
  }

  /// Quét danh sách WiFi xung quanh
  static Future<List<WifiNetwork>> scanForDeviceWifi(
      {List<String> prefixes = const ["AV", "Vuelogic"]}) async {
    if (Platform.isIOS) {
      return []; // iOS không hỗ trợ quét danh sách WiFi
    }

    bool hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      print("Permission denied. Cannot scan for WiFi.");
      return [];
    }

    try {
      bool isWifiEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isWifiEnabled) {
        print("WiFi is disabled. Returning empty list without prompting.");
        return [];
      }
    } catch (e) {
      print("Could not check WiFi status: $e");
      return [];
    }

    try {
      // Bắt đầu quét mạng
      List<WifiNetwork> wifiList = await WiFiForIoTPlugin.loadWifiList();

      // Lọc các WiFi có tên bắt đầu bằng các prefix (Ví dụ: AV01, Vuelogic...)
      return wifiList.where((wifi) {
        if (wifi.ssid == null || wifi.ssid!.isEmpty) return false;
        String ssidUpper = wifi.ssid!.toUpperCase();
        for (String prefix in prefixes) {
          if (ssidUpper.startsWith(prefix.toUpperCase())) {
            return true;
          }
        }
        return false;
      }).toList();
    } catch (e) {
      print("Error scanning WiFi: $e");
      return [];
    }
  }

  /// Kết nối vào mạng WiFi cụ thể
  static Future<bool> connectToWifi(String ssid, {String password = ""}) async {
    if (Platform.isIOS) return false;

    try {
      // xóa mạng cũ trước khi kết nối
      await WiFiForIoTPlugin.removeWifiNetwork(ssid);

      // Kết nối
      bool result = await WiFiForIoTPlugin.connect(
        ssid,
        password: password.isNotEmpty ? password : null,
        security:
            password.isNotEmpty ? NetworkSecurity.WPA : NetworkSecurity.NONE,
        joinOnce: true,
        withInternet: false,
      );

      // Ép Android định tuyến dữ liệu qua WiFi này
      if (result) {
        await WiFiForIoTPlugin.forceWifiUsage(true);
        await Future.delayed(const Duration(seconds: 3));
      }
      return result;
    } catch (e) {
      print("Error connecting to WiFi $ssid: $e");
      return false;
    }
  }

  /// Ngắt kết nối WiFi hiện tại
  static Future<void> disconnectWifi() async {
    if (Platform.isIOS) return;
    try {
      // Bắt buộc phải nhả quyền "Ép dùng WiFi" ra trước khi ngắt kết nối.
      // Nếu không, Android vẫn giữ App kẹt ở luồng mạng cũ, gây mất mạng Internet
      // cho đến khi Kill App (tắt hẳn ứng dụng).
      await WiFiForIoTPlugin.forceWifiUsage(false);
      await WiFiForIoTPlugin.disconnect();
    } catch (e) {
      print("Error disconnecting WiFi: $e");
    }
  }

  static Future<void> forceWifiUsage(bool useWifi) async {
    if (Platform.isIOS) return;
    try {
      await WiFiForIoTPlugin.forceWifiUsage(useWifi);
    } catch (e) {
      print("Error forcing WiFi usage: $e");
    }
  }

  // --- Hỗ trợ lưu mật khẩu WiFi để lần sau tự động kết nối ---
  static const String _wifiPwdPrefix = "WIFI_PWD_";

  static Future<void> saveWifiPassword(String ssid, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_wifiPwdPrefix$ssid', password);
  }

  static Future<String?> getSavedWifiPassword(String ssid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_wifiPwdPrefix$ssid');
  }
}

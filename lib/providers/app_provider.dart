import 'package:new_renitek/providers/mixins/app_provider_state.dart';
import 'package:new_renitek/providers/mixins/ble_manager_mixin.dart';
import 'package:new_renitek/providers/mixins/device_control_mixin.dart';
import 'package:new_renitek/providers/mixins/ota_update_mixin.dart';
import 'package:new_renitek/providers/mixins/wifi_socket_mixin.dart';
import 'package:new_renitek/service/storage_service.dart';

class AppProvider extends AppProviderState
    with
        BleManagerMixin,
        WifiSocketMixin,
        OtaUpdateMixin,
        DeviceControlMixin {
  
  Future<void> getSaveName() async {
    final result = await StorageService.getSaveName();
    if (result != null) {
      renameMap = result;
      print('Loaded renameMap: $renameMap');
      notifyListeners();
    } else {
      print('No saved renameMap found');
    }
  }

  void getSaveDevice() async {
    final result = await StorageService.getDeviceList();
    saveDeviceList = result;

    isLatestFirmware = await StorageService.getIsLatestFirmware();
    isExpertMode = await StorageService.getExpertMode();

    notifyListeners();
  }

  void toggleExpertMode(bool value) {
    isExpertMode = value;
    StorageService.saveExpertMode(value);
    notifyListeners();
  }

  void saveDeviceName(String deviceName, String saveName) async {
    print('Saving device name: "$deviceName" -> "$saveName"');
    renameMap[deviceName] = saveName;
    print('Updated renameMap: $renameMap');
    StorageService.saveName(renameMap);
    notifyListeners();
  }
}

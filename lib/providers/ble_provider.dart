import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:reintechnik/service/ble_service.dart';

class BLEProvider extends ChangeNotifier {
  List<BluetoothDevice> bleDeviceList = [];
  BluetoothDevice? bluetoothDevice;
  BluetoothCharacteristic? bluetoothCharacteristic;
  void scanDevice() async {
    bleDeviceList = await BLEService.instance.startScanDevice();
    notifyListeners();
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      bluetoothDevice = device;

      // device.state.listen(
      //   (event) {
      //     if (event == BluetoothDeviceState.disconnected) {
      //       bluetoothDevice = null;
      //       notifyListeners();
      //     }
      //   },
      // );
      discoveryService(device);
    } catch (e) {
      print(e);
    }
  }

  void discoveryService(BluetoothDevice device) async {
    bluetoothCharacteristic = await BLEService.instance.discoverService(device);
    notifyListeners();
  }
}

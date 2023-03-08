import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/models/status_of_motor.dart';
import 'package:reintechnik/models/wifi.dart';

abstract class DataBulletTin {
  const factory DataBulletTin.wifiStatus({String? payload}) =
      WifiStatusBulletin;
  const factory DataBulletTin.motorStatus({String? payload}) =
      MotorStatusBulletin;
  const factory DataBulletTin.scannedWifiBulletin({String? payload}) =
      ScannedWifiListBulletin;
}

class WifiStatusBulletin implements DataBulletTin {
  const WifiStatusBulletin(
      {this.header =
          BLERespondConst.RESPOND_HEADER + BLERespondConst.WIFI_STATUS_ID,
      this.payload});

  final String header;
  final String? payload;
}

class MotorStatusBulletin implements DataBulletTin {
  const MotorStatusBulletin(
      {this.header =
          BLERespondConst.RESPOND_HEADER + BLERespondConst.MOTOR_STATUS_ID,
      this.payload});
  final String header;
  final String? payload;
}

class ScannedWifiListBulletin implements DataBulletTin {
  const ScannedWifiListBulletin(
      {this.header =
          BLERespondConst.RESPOND_HEADER + BLERespondConst.SCAN_WIFI_LIST_ID,
      this.payload});
  final String header;
  final String? payload;
}

extension GetWifiStatusData on ScannedWifiListBulletin {
  Wifi getWifiData() {
    return Wifi(name: payload!);
  }
}

extension GetListDataData on WifiStatusBulletin {}

extension GetMototStatusData on MotorStatusBulletin {
  MotorStatus getMotorStatus() {
    final status = int.parse(payload!.substring(0, 1));
    final postion = int.parse(payload!.substring(1, 4));

    final motorStatus = MotorStatus(position: postion, status: status);
    return motorStatus;
  }
}

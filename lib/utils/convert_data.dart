import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/models/data_bulletin.dart';

DataBulletTin? getDataBulletin(List<int> rawData) {
  final tranferData = String.fromCharCodes(rawData);
  print(tranferData);
  if (tranferData.length < 3) {
    return null;
  }
  final splitStringList = tranferData.split(":");

  final header = splitStringList[0];
  String payLoad = splitStringList[1];
  //Get last index of footer !
  final subIndex = payLoad.lastIndexOf("!");
  payLoad = payLoad.substring(0, subIndex);

  if (header ==
      BLERespondConst.RESPOND_HEADER_ID + BLERespondConst.MOTOR_STATUS_ID) {
    return DataBulletTin.motorStatus(payload: payLoad);
  } else if (header ==
      BLERespondConst.RESPOND_HEADER_ID + BLERespondConst.WIFI_STATUS_ID) {
    return DataBulletTin.wifiStatus(payload: payLoad);
  } else if (header ==
      BLERespondConst.RESPOND_HEADER_ID + BLERespondConst.SCAN_WIFI_LIST_ID) {
    return DataBulletTin.scannedWifiBulletin(payload: payLoad);
  } else if (header ==
      BLERespondConst.RESPOND_HEADER_ID + BLERespondConst.TCP_ID) {
    return DataBulletTin.tcpSocketIp(payload: payLoad);
  } else if (header ==
      BLERespondConst.RESPOND_HEADER_ID + BLERespondConst.FIRMWARE_VERSION_ID) {
    return DataBulletTin.firmWareVersion(payload: payLoad);
  }
  return null;
}

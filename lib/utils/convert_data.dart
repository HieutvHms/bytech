import 'package:new_renitek/const/ble_const.dart';
import 'package:new_renitek/models/data_bulletin.dart';

DataBulletTin? getDataBulletin(List<int> rawData) {
  final tranferData = String.fromCharCodes(rawData);
  print(tranferData);
  if (tranferData.length < 3) {
    return null;
  }
  // ---- ĐOẠN CODE CŨ (Đã bị comment out vì gây lỗi crash nếu thiếu dấu ! hoặc :) ----
  // final splitStringList = tranferData.split(":");
  // final header = splitStringList[0];
  // String payLoad = splitStringList[1];
  // //Get last index of footer !
  // final subIndex = payLoad.lastIndexOf("!");
  // payLoad = payLoad.substring(0, subIndex);
  // ---------------------------------------------------------------------------------

  final colonIndex = tranferData.indexOf(":");
  if (colonIndex == -1) {
    return null;
  }

  final header = tranferData.substring(0, colonIndex);
  String payLoad = tranferData.substring(colonIndex + 1);

  //Get last index of footer !
  final subIndex = payLoad.lastIndexOf("!");
  if (subIndex != -1) {
    payLoad = payLoad.substring(0, subIndex);
  } else {
    // Dữ liệu bị cắt cụt hoặc thiếu dấu !, bỏ qua để không bị crash
    print("Warning: Missing '!' footer in payload, skipping.");
    return null;
  }

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

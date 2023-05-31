import 'package:flutter/material.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';

enum WifiStatusEnum {
  FAIL_CONNECT,
  SUCCESS_CONNECT,
  CONNECTING,
}

class WifiConnectStatus {
  final String? ssidNameConnect;
  final WifiStatusEnum? wifiStatusEnum;

  WifiConnectStatus({this.ssidNameConnect, this.wifiStatusEnum});

  String getStatusWifi() {
    switch (wifiStatusEnum) {
      case WifiStatusEnum.SUCCESS_CONNECT:
        return 'Kết nối thành công';
      case WifiStatusEnum.CONNECTING:
        return 'Đang kết nối wifi ...';
      case WifiStatusEnum.FAIL_CONNECT:
        return 'Kết nối thất bại';
      default:
        return 'Lỗi không xác định';
    }
  }

  Text getStatusTextWifi() {
    switch (wifiStatusEnum) {
      case WifiStatusEnum.SUCCESS_CONNECT:
        return Text(
          'Kết nối thành công',
          style: CustomTextStyle.bodyMedium
              .copyWith(color: CustomColor.stateGreen),
        );
      case WifiStatusEnum.CONNECTING:
        return Text(
          'Đang kết nối ... ',
          style: CustomTextStyle.bodyMedium
              .copyWith(color: CustomColor.stateYellow),
        );
      case WifiStatusEnum.FAIL_CONNECT:
        return Text(
          'Kết nối thất bại',
          style:
              CustomTextStyle.bodyMedium.copyWith(color: CustomColor.stateRed),
        );
      default:
        return Text(
          'Kết nối thất bại',
          style:
              CustomTextStyle.bodyMedium.copyWith(color: CustomColor.stateRed),
        );
    }
  }
}

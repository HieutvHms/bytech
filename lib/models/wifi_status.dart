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
        return 'Kết nối wifi $ssidNameConnect thành công';
      case WifiStatusEnum.CONNECTING:
        return 'Đang kết nối wifi $ssidNameConnect ...';
      case WifiStatusEnum.FAIL_CONNECT:
        return 'Kết nối wifi $ssidNameConnect thất bại';
      default:
        return 'Lỗi không xác định';
    }
  }
}

enum WifiStatusEnum {
  FAIL_CONNECT,
  SUCCESS_CONNECT,
  CONNECTING,
}

class WifiConnectStatus {
  final String? ssidNameConnect;
  final WifiStatusEnum? wifiStatusEnum;

  WifiConnectStatus({this.ssidNameConnect, this.wifiStatusEnum});
}

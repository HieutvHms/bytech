// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:convert';

enum ControlType { GO_IN, GO_OUT, STOP }

class BLERequestConst {
  static List<int> ID_PAYLOAD_DIVIVDER = utf8.encode(':');
  static List<int> DASH = utf8.encode('-');
  //HEADER :

  static List<int> CONTROL_HEADER = utf8.encode('#');

  //ID:
  static List<int> CONTROL_ID = utf8.encode('0');
  static List<int> CONFIG_WIFI_ID = utf8.encode('1');
  static List<int> SCAN_WIFI_ID = utf8.encode('2');

  //Footer
  static List<int> FOOTER = utf8.encode('!');
  //Command:
  static List<int> GO_IN_COMMAND = utf8.encode('01');
  static List<int> GO_OUT_COMMAND = utf8.encode('11');
  static List<int> STOP_COMMAND = utf8.encode('00');
}

class BLERespondConst {
  static const String RESPOND_HEADER = '\$';

  static const String WIFI_STATUS_ID = '1';
  static const String MOTOR_STATUS_ID = '2';
  static const String SCAN_WIFI_LIST_ID = '3';
}

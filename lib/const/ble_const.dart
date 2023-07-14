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

  static List<int> UPDATE_FIRMWARE =
      utf8.encode('#5:http://27.71.226.192:2602/AV03_NEW_HW.bin!');
}

class BLERespondConst {
  static const String RESPOND_HEADER_ID = '\$';
  static const String FIRMWARE_VERSION_ID = '0';
  static const String WIFI_STATUS_ID = '1';
  static const String MOTOR_STATUS_ID = '2';
  static const String SCAN_WIFI_LIST_ID = '3';
  static const String TCP_ID = '4';
}

import 'package:reintechnik/const/ble_const.dart';

extension GetCommand on ControlType {
  List<int> getCommand() {
    switch (this) {
      case ControlType.GO_IN:
        return BLERequestConst.GO_IN_COMMAND;
      case ControlType.GO_OUT:
        return BLERequestConst.GO_OUT_COMMAND;
      case ControlType.STOP:
        return BLERequestConst.STOP_COMMAND;
    }
  }
}

import 'package:reintechnik/const/ble_const.dart';

extension GetCommand on ControlType {
  List<int> getCommand() {
    switch (this) {
      case ControlType.GO_IN:
        return BLEConst.GO_IN_COMMAND;
      case ControlType.GO_OUT:
        return BLEConst.GO_OUT_COMMAND;
      case ControlType.STOP:
        return BLEConst.STOP_COMMAND;
    }
  }
}

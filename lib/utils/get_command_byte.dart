import 'package:new_renitek/const/ble_const.dart';
import 'package:new_renitek/utils/get_command.dart';

List<int> getCommandByte(ControlType controlType) {
  List<int> command = [];

  command.addAll(BLERequestConst.CONTROL_HEADER);
  command.addAll(BLERequestConst.CONTROL_ID);
  command.addAll(BLERequestConst.ID_PAYLOAD_DIVIVDER);
  command.addAll(controlType.getCommand());

  command.addAll(BLERequestConst.FOOTER);
  return command;
}

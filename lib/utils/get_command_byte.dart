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

List<int> getVersionRequestCommand() {
  List<int> command = [];

  command.addAll(BLERequestConst.CONTROL_HEADER);
  // Assuming '0' is the command ID for version based on BLERespondConst.FIRMWARE_VERSION_ID
  command.addAll(BLERequestConst.CONTROL_ID); 
  command.addAll(BLERequestConst.ID_PAYLOAD_DIVIVDER);
  // Adjust this payload if the device expects a specific command for version request
  command.addAll([0x30]); // ascii '0' placeholder
  
  command.addAll(BLERequestConst.FOOTER);
  return command;
}


import 'package:reintechnik/models/status_of_motor.dart';

MotorStatus? convertRawData(List<int> rawData) {
  final tranferData = String.fromCharCodes(rawData);
  final splitStringList = tranferData.split(":");
  final header = splitStringList[0];
  //TODO : THIS is test logic try to remove
  if (header == "\$2") {
    final payload = splitStringList[1].substring(0, 4);

    final status = int.parse(payload.substring(0, 1));
    final postion = int.parse(payload.substring(1, 4));

    final motorStatus = MotorStatus(position: postion, status: status);
    return motorStatus;
  } else {
    return null;
  }
}

// ignore_for_file: constant_identifier_names

enum StatusOfMotorEnum {
  STOP_STATUS,
  MOVE_IN_STATUS,
  MOVE_OUT_STATUS,
  IS_MOVING_STATUS,
  STUCK_STATUS,
}

class MotorStatus {
  final int status;
  final int position;

  MotorStatus({
    required this.status,
    required this.position,
  });

  String getStatus() {
    if (isRunning()) {
      return "Động cơ đang dừng lại";
    } else if (status == StatusOfMotorEnum.MOVE_IN_STATUS.index) {
      return "Động cơ đang đi vào";
    } else if (status == StatusOfMotorEnum.MOVE_OUT_STATUS.index) {
      return "Động cơ đang  đi ra";
    } else if (status == StatusOfMotorEnum.STUCK_STATUS.index) {
      return "Động cơ đang bị kẹt";
    } else {
      return "Trạng thái chưa xác định";
    }
  }

  bool canMoveIn() {
    return position <= 100 && position > 0;
  }

  bool canMoveOut() {
    return position >= 0 && position < 100;
  }

  bool isRunning() {
    return status == StatusOfMotorEnum.STOP_STATUS.index ||
        position == 0 ||
        position == 100;
  }
}

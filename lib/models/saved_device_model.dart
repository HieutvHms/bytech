enum DeviceType { BLE, MDNS }

class SavedDeviceModel {
  final String deviceName;
  final DeviceType deviceType;

  SavedDeviceModel({
    required this.deviceName,
    required this.deviceType,
  });
  Map<String, dynamic> toJson() {
    return {"DeviceName": deviceName, "DeviceType": deviceType.index};
  }

  factory SavedDeviceModel.fromJson(Map<String, dynamic> json) {
    return SavedDeviceModel(
      deviceName: json["DeviceName"],
      deviceType: DeviceType.values[json["DeviceType"]],
    );
  }
}

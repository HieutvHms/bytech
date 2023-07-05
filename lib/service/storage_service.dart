import 'dart:convert';

import 'package:reintechnik/models/saved_device_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const renameKey = "rename";
const saveListKey = "saveListKey";

class StorageService {
  static Future<Map<String, dynamic>?> getSaveName() async {
    final shared = await SharedPreferences.getInstance();
    final result = shared.getString(renameKey);
    if (result != null) {
      final map = json.decode(result);

      return map as Map<String, dynamic>;
    }
    return null;
  }

  static void saveName(Map<String, dynamic> nameMap) async {
    final shared = await SharedPreferences.getInstance();
    print(json.encode(nameMap).runtimeType);
    shared.setString(renameKey, json.encode(nameMap));
  }

  static void saveDeviceList(List<SavedDeviceModel> saveList) async {
    final shared = await SharedPreferences.getInstance();
    final saveData = saveList.map((e) => json.encode(e.toJson())).toList();
    shared.setStringList(saveListKey, saveData);
  }

  static Future<List<SavedDeviceModel>> getDeviceList() async {
    final shared = await SharedPreferences.getInstance();

    final data = shared.getStringList(saveListKey);
    if (data == null) {
      return [];
    }
    return data.map((e) => SavedDeviceModel.fromJson(json.decode(e))).toList();
  }
}

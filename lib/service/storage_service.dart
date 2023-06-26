import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const renameKey = "rename";

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
}

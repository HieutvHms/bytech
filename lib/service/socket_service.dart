import 'dart:convert';
import 'dart:io';

import 'package:new_renitek/const/ble_const.dart';
import 'package:new_renitek/utils/get_command_byte.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();
  Future<Socket> connect(
      String host, int port, Function(List<int> event) alyticData) async {
    final socket =
        await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    socket.listen((event) {
      final listInt = event.toList();
      alyticData(listInt);
    });
    return socket;
  }

  void controlDevice(Socket socket, ControlType controlType) {
    try {
      List<int> command = getCommandByte(controlType);
      final commandString = String.fromCharCodes(command);
      socket.write(commandString);
    } catch (e) {
      rethrow;
    }
  }

  void updateFirmWare({required Socket socket, String? url}) {
    if (url == null)
    {
      return;
    }
    try {
      List<int> command =
          url != null ? utf8.encode(url) : BLERequestConst.UPDATE_FIRMWARE;
      final commandString = String.fromCharCodes(command);
      socket.write(commandString);
    } catch (e) {
      rethrow;
    }
  }

  void disconnect(Socket socket) {
    socket.close();
  }
}

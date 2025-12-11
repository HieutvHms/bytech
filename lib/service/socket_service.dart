import 'dart:io';

import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/utils/get_command_byte.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();
  Future<Socket> connect(String host, int port, Function(List<int> event) alyticData) async {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
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

  void updateFirmWare(Socket socket, String updateUrl) {
    try {
      final commandString = "#5:$updateUrl!";
      socket.write(commandString);
    } catch (e) {
      rethrow;
    }
  }

  void disconnect(Socket socket) {
    socket.close();
  }
}

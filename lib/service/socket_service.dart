import 'dart:convert';
import 'dart:io';

import 'package:new_renitek/const/ble_const.dart';
import 'package:new_renitek/utils/get_command_byte.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();
  Future<Socket> connect(
      String host, int port, Function(List<int> event) alyticData) async {
    print('====================================');
    print('🛠 DEBUG: Connecting to Socket -> IP: $host, Port: $port');
    print('====================================');
    try {
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      print('✅ Socket Connected Successfully!');
      socket.listen((event) {
        final listInt = event.toList();
        alyticData(listInt);
      }, onError: (error) {
        print('❌ Socket Listen Error: $error');
      }, onDone: () {
        print('⚠️ Socket Connection Closed by server');
      });
      return socket;
    } catch (e) {
      print('❌ Socket Connection Failed: $e');
      rethrow;
    }
  }

  void controlDevice(Socket socket, ControlType controlType) {
    try {
      List<int> command = getCommandByte(controlType);

      // OLD CODE:
      // final commandString = String.fromCharCodes(command);
      // socket.write(commandString);

      // NEW CODE:
      print('TCP SEND (control): ${String.fromCharCodes(command)}');
      socket.add(command); // Gửi raw bytes thay vì chuyển sang String
    } catch (e) {
      rethrow;
    }
  }

  void updateFirmWare({required Socket socket, String? url}) {
    if (url == null) {
      return;
    }
    try {
      List<int> command = utf8.encode(url);

      // OLD CODE:
      // final commandString = String.fromCharCodes(command);
      // socket.write(commandString);

      // NEW CODE:
      print('TCP SEND (firmware): ${String.fromCharCodes(command)}');
      socket.add(command); // Gửi raw bytes
    } catch (e) {
      rethrow;
    }
  }

  void disconnect(Socket socket) {
    socket.close();
  }
}

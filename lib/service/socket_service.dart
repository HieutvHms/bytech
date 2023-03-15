import 'dart:io';

class SocketService {
  void connect(String host, int port) async {
    ServerSocket.bind(host, port);
  }

  void listen(ServerSocket socket) {
    socket.listen((event) {});
  }
}

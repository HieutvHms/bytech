import 'dart:io';

class SocketService {
  Future<void> connect(String host, int port) async {
    await Socket.connect(host, port).then((socket) {
      listen(socket);
    });
  }

  void listen(Socket socket) {
    socket.listen((event) {});
  }
}

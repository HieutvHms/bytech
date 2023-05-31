import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> isConnectedInternet() async {
  final connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult == ConnectivityResult.wifi ||
      connectivityResult == ConnectivityResult.ethernet) {
    return true;
  }
  return false;
}

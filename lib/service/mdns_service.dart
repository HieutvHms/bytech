import 'package:nsd/nsd.dart';

class MdnsService {
  Future<Discovery> startDiscoveryMDNS() async {
    final discovery = await startDiscovery('_http._tcp');
    return discovery;
  }
}

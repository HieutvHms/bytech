import 'dart:convert';

import 'package:http/http.dart' as http;

class LogsService {
  static const String baseUrl = 'http://42.96.40.74:8899';
  static const String logsEndpoint = '/logs';
  static const String firmwareCheckEndpoint = '/firmware/check';

  /// Send a POST request to the logs endpoint
  /// Equivalent to: curl -X 'POST' 'http://42.96.40.74:8899/logs' -H 'accept: application/json' -d ''
  // static Future<http.Response> postLogs() async {
  //   try {
  //     final Uri url = Uri.parse('$baseUrl$logsEndpoint');

  //     final response = await http.post(
  //       url,
  //       headers: {
  //         'Accept': 'application/json',
  //       },
  //       body: '',
  //     );

  //     return response;
  //   } catch (e) {
  //     throw Exception('Failed to send logs request: $e');
  //   }
  // }

  /// Send a POST request to the firmware check endpoint
  /// Equivalent to: curl -X 'POST' 'http://42.96.40.74:8899/firmware/check' -H 'accept: application/json' -H 'Content-Type: application/json' -d '{"mac": "string", "version": "AVMotor 000"}'
  static Future<http.Response> postFirmwareCheck({
    required String mac,
    required String version,
  }) async {
    try {
      final Uri url = Uri.parse('$baseUrl$firmwareCheckEndpoint');

      final requestBody = {
        'mac': mac,
        'version': version,
      };

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      return response;
    } catch (e) {
      throw Exception('Failed to send firmware check request: $e');
    }
  }

  /// Send a POST request to the firmware check endpoint and parse the response
  static Future<Map<String, dynamic>?> postFirmwareCheckWithResponse({
    required String mac,
    required String version,
  }) async {
    try {
      final response = await postFirmwareCheck(mac: mac, version: version);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isNotEmpty) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        return null;
      } else {
        throw Exception(
            'HTTP Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to process firmware check response: $e');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/network.dart';

/// Client for the wifi-connect HTTP API.
///
/// Endpoints:
///   GET  /networks  — returns available Wi-Fi networks
///   POST /connect   — connects to a chosen network
class WifiConnectApi {
  /// Base URL is relative (same origin) when running as the captive portal UI.
  /// Override for local development against a running wifi-connect instance.
  final String baseUrl;

  WifiConnectApi({this.baseUrl = ''});

  /// Fetches the list of available Wi-Fi networks.
  Future<List<Network>> fetchNetworks() async {
    final response = await http.get(Uri.parse('$baseUrl/networks'));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch networks: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => Network.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends a connect request to join the specified network.
  ///
  /// After a successful call the wifi-connect backend tears down the captive
  /// portal AP and attempts to join [ssid]. The HTTP server becomes
  /// unreachable, so no further requests should be expected.
  Future<void> connect({
    required String ssid,
    String identity = '',
    String passphrase = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/connect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'ssid': ssid,
        'identity': identity,
        'passphrase': passphrase,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to connect: ${response.statusCode} ${response.reasonPhrase}',
      );
    }
  }
}

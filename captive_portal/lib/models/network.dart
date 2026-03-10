/// Represents a Wi-Fi network returned by the wifi-connect API.
class Network {
  final String ssid;
  final String security;

  const Network({required this.ssid, required this.security});

  factory Network.fromJson(Map<String, dynamic> json) {
    return Network(
      ssid: json['ssid'] as String,
      security: json['security'] as String,
    );
  }

  bool get isEnterprise => security == 'enterprise';
  bool get isOpen => security == 'none';
  bool get needsPassphrase => !isOpen;

  @override
  String toString() => 'Network(ssid: $ssid, security: $security)';
}

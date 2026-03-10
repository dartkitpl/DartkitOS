import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config.dart';
import '../models/network.dart';
import '../services/wifi_connect_api.dart';

// ── State ──────────────────────────────────────────────────────────────

class WifiSetupState {
  final List<Network>? networks;
  final Network? selectedNetwork;
  final bool isLoading;
  final bool isConnecting;
  final bool connected;
  final bool obscurePassphrase;
  final String? error;
  final String passphrase;
  final String identity;

  const WifiSetupState({
    this.networks,
    this.selectedNetwork,
    this.isLoading = true,
    this.isConnecting = false,
    this.connected = false,
    this.obscurePassphrase = true,
    this.error,
    this.passphrase = '',
    this.identity = '',
  });

  // Derived state
  bool get showIdentity =>
      selectedNetwork != null && selectedNetwork!.isEnterprise;

  bool get showPassphrase =>
      selectedNetwork != null && selectedNetwork!.needsPassphrase;

  WifiSetupState copyWith({
    List<Network>? networks,
    Network? selectedNetwork,
    bool? isLoading,
    bool? isConnecting,
    bool? connected,
    bool? obscurePassphrase,
    String? error,
    String? passphrase,
    String? identity,
    bool clearError = false,
    bool clearSelectedNetwork = false,
  }) {
    return WifiSetupState(
      networks: networks ?? this.networks,
      selectedNetwork: clearSelectedNetwork
          ? selectedNetwork
          : (selectedNetwork ?? this.selectedNetwork),
      isLoading: isLoading ?? this.isLoading,
      isConnecting: isConnecting ?? this.isConnecting,
      connected: connected ?? this.connected,
      obscurePassphrase: obscurePassphrase ?? this.obscurePassphrase,
      error: clearError ? null : (error ?? this.error),
      passphrase: passphrase ?? this.passphrase,
      identity: identity ?? this.identity,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────

class WifiSetupNotifier extends Notifier<WifiSetupState> {
  late final WifiConnectApi _api;

  @override
  WifiSetupState build() {
    _api = ref.read(wifiConnectApiProvider);
    // Kick off initial network scan.
    Future.microtask(() => loadNetworks());
    return const WifiSetupState();
  }

  Future<void> loadNetworks() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _api.fetchNetworks();
      state = state.copyWith(
        networks: result,
        isLoading: false,
        selectedNetwork: result.isNotEmpty ? result.first : null,
        clearSelectedNetwork: result.isEmpty,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to fetch available networks. $e',
        isLoading: false,
      );
    }
  }

  void selectNetwork(Network? network) {
    state = state.copyWith(
      selectedNetwork: network,
      clearSelectedNetwork: network == null,
      passphrase: '',
      identity: '',
    );
  }

  void setPassphrase(String value) {
    state = state.copyWith(passphrase: value);
  }

  void setIdentity(String value) {
    state = state.copyWith(identity: value);
  }

  void toggleObscurePassphrase() {
    state = state.copyWith(obscurePassphrase: !state.obscurePassphrase);
  }

  Future<void> connect() async {
    final network = state.selectedNetwork;
    if (network == null) return;

    state = state.copyWith(isConnecting: true, clearError: true);

    try {
      await _api.connect(
        ssid: network.ssid,
        identity: state.identity,
        passphrase: state.passphrase,
      );
      state = state.copyWith(isConnecting: false, connected: true);
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to connect to the network. $e',
      );
    }
  }
}

// ── Providers ──────────────────────────────────────────────────────────

final wifiConnectApiProvider = Provider<WifiConnectApi>((ref) {
  return WifiConnectApi(baseUrl: AppConfig.apiBaseUrl);
});

final wifiSetupProvider = NotifierProvider<WifiSetupNotifier, WifiSetupState>(
  WifiSetupNotifier.new,
);

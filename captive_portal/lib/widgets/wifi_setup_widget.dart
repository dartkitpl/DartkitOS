import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/network.dart';
import 'wifi_setup_viewmodel.dart';

/// Root widget for the Wi-Fi captive-portal setup flow.
///
/// Stateless [ConsumerWidget] — all mutable state lives in [WifiSetupNotifier].
class WifiSetupWidget extends ConsumerWidget {
  const WifiSetupWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wifiSetupProvider);
    final notifier = ref.read(wifiSetupProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Setup'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _buildBody(context, state, notifier),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Body router ────────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    WifiSetupState state,
    WifiSetupNotifier notifier,
  ) {
    final theme = Theme.of(context);

    if (state.connected) return _buildConnectedView(theme);
    if (state.isLoading) return _buildLoadingView();
    if (state.error != null && state.networks == null) {
      return _buildErrorRetry(theme, state, notifier);
    }
    if (state.networks != null && state.networks!.isEmpty) {
      return _buildNoNetworks(theme, notifier);
    }
    return _buildForm(theme, state, notifier);
  }

  // ─── Sub-views ──────────────────────────────────────────────────────

  Widget _buildConnectedView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('Applying changes…', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Your device will soon be online. If connection is unsuccessful, '
            'the access point will reappear in a few minutes — reload this '
            'page to try again.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Scanning for networks…'),
        ],
      ),
    );
  }

  Widget _buildErrorRetry(
    ThemeData theme,
    WifiSetupState state,
    WifiSetupNotifier notifier,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(state.error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: notifier.loadNetworks,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoNetworks(ThemeData theme, WifiSetupNotifier notifier) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          const Text(
            'No Wi-Fi networks found.\n'
            'Make sure there is a network in range and try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: notifier.loadNetworks,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan again'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    ThemeData theme,
    WifiSetupState state,
    WifiSetupNotifier notifier,
  ) {
    return ListView(
      children: [
        Text(
          'Choose your Wi-Fi network',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // --- Error banner ---
        if (state.error != null) ...[
          _errorBanner(theme, state),
          const SizedBox(height: 16),
        ],

        // --- SSID dropdown ---
        DropdownButtonFormField<Network>(
          decoration: const InputDecoration(
            labelText: 'Network',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.wifi),
          ),
          value: state.selectedNetwork,
          items: state.networks!
              .map((n) => DropdownMenuItem(value: n, child: Text(n.ssid)))
              .toList(),
          onChanged: notifier.selectNetwork,
        ),
        const SizedBox(height: 16),

        // --- Identity (enterprise only) ---
        if (state.showIdentity) ...[
          TextFormField(
            initialValue: state.identity,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            textInputAction: TextInputAction.next,
            onChanged: notifier.setIdentity,
          ),
          const SizedBox(height: 16),
        ],

        // --- Passphrase ---
        if (state.showPassphrase) ...[
          TextFormField(
            initialValue: state.passphrase,
            obscureText: state.obscurePassphrase,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  state.obscurePassphrase
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: notifier.toggleObscurePassphrase,
              ),
            ),
            textInputAction: TextInputAction.done,
            onChanged: notifier.setPassphrase,
            onFieldSubmitted: (_) => notifier.connect(),
          ),
          const SizedBox(height: 24),
        ],

        // --- Connect button ---
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: state.isConnecting ? null : notifier.connect,
            child: state.isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Connect'),
          ),
        ),
      ],
    );
  }

  Widget _errorBanner(ThemeData theme, WifiSetupState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.error!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

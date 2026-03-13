import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/network.dart';
import 'wifi_setup_viewmodel.dart';

/// Root widget for the Wi-Fi captive-portal setup flow.
///
/// Stateless [ConsumerWidget] — all mutable state lives in [WifiSetupNotifier].
/// Optimized for mobile captive portal webviews (Android/iOS).
class WifiSetupWidget extends ConsumerWidget {
  const WifiSetupWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wifiSetupProvider);
    final notifier = ref.read(wifiSetupProvider.notifier);
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isSmallScreen = mediaQuery.size.shortestSide < 600;

    return Scaffold(
      // Resize when keyboard appears on mobile
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Wi-Fi Setup'),
        centerTitle: true,
        // Make app bar taller on touch devices for better tap targets
        toolbarHeight: isSmallScreen ? 56 : 64,
      ),
      body: SafeArea(
        // Ensure content doesn't overlap with notches/safe areas
        minimum: const EdgeInsets.all(8),
        child: Center(
          child: ConstrainedBox(
            // Wider max width for landscape mode
            constraints: BoxConstraints(maxWidth: isLandscape ? 600 : 480),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
                vertical: isSmallScreen ? 12 : 16,
              ),
              child: _buildBody(context, state, notifier, isSmallScreen),
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
    bool isSmallScreen,
  ) {
    final theme = Theme.of(context);

    if (state.connected) return _buildConnectedView(theme, isSmallScreen);
    if (state.isLoading) return _buildLoadingView(isSmallScreen);
    if (state.error != null && state.networks == null) {
      return _buildErrorRetry(theme, state, notifier, isSmallScreen);
    }
    if (state.networks != null && state.networks!.isEmpty) {
      return _buildNoNetworks(theme, notifier, isSmallScreen);
    }
    return _buildForm(theme, state, notifier, isSmallScreen);
  }

  // ─── Sub-views ──────────────────────────────────────────────────────

  Widget _buildConnectedView(ThemeData theme, bool isSmallScreen) {
    final iconSize = isSmallScreen ? 56.0 : 64.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: iconSize,
              color: theme.colorScheme.primary,
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              'Applying changes…',
              style: isSmallScreen
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.headlineSmall,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'Your device will soon be online. If connection is unsuccessful, '
              'the access point will reappear in a few minutes — reload this '
              'page to try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: isSmallScreen ? 36 : 44,
            height: isSmallScreen ? 36 : 44,
            child: const CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          Text(
            'Scanning for networks…',
            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorRetry(
    ThemeData theme,
    WifiSetupState state,
    WifiSetupNotifier notifier,
    bool isSmallScreen,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: isSmallScreen ? 44 : 48,
              color: theme.colorScheme.error,
            ),
            SizedBox(height: isSmallScreen ? 10 : 12),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
            SizedBox(height: isSmallScreen ? 14 : 16),
            FilledButton.icon(
              onPressed: notifier.loadNetworks,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoNetworks(
      ThemeData theme, WifiSetupNotifier notifier, bool isSmallScreen) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off,
              size: isSmallScreen ? 44 : 48,
              color: theme.colorScheme.error,
            ),
            SizedBox(height: isSmallScreen ? 10 : 12),
            Text(
              'No Wi-Fi networks found.\n'
              'Make sure there is a network in range and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
            SizedBox(height: isSmallScreen ? 14 : 16),
            FilledButton.icon(
              onPressed: notifier.loadNetworks,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    ThemeData theme,
    WifiSetupState state,
    WifiSetupNotifier notifier,
    bool isSmallScreen,
  ) {
    final verticalSpacing = isSmallScreen ? 12.0 : 16.0;
    final sectionSpacing = isSmallScreen ? 20.0 : 24.0;

    return ListView(
      // Ensure scrolling works well in captive portal webviews
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'Choose your Wi-Fi network',
          style: isSmallScreen
              ? theme.textTheme.titleLarge
              : theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: sectionSpacing),

        // --- Error banner ---
        if (state.error != null) ...[
          _errorBanner(theme, state, isSmallScreen),
          SizedBox(height: verticalSpacing),
        ],

        // --- SSID dropdown ---
        DropdownButtonFormField<Network>(
          decoration: InputDecoration(
            labelText: 'Network',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.wifi),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isSmallScreen ? 14 : 16,
            ),
          ),
          isExpanded: true, // Prevent overflow on narrow screens
          value: state.selectedNetwork,
          items: state.networks!
              .map((n) => DropdownMenuItem(
                    value: n,
                    child: Text(
                      n.ssid,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: notifier.selectNetwork,
        ),
        SizedBox(height: verticalSpacing),

        // --- Identity (enterprise only) ---
        if (state.showIdentity) ...[
          TextFormField(
            initialValue: state.identity,
            decoration: InputDecoration(
              labelText: 'Username',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmallScreen ? 14 : 16,
              ),
            ),
            textInputAction: TextInputAction.next,
            autocorrect: false,
            onChanged: notifier.setIdentity,
          ),
          SizedBox(height: verticalSpacing),
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmallScreen ? 14 : 16,
              ),
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
            autocorrect: false,
            enableSuggestions: false,
            onChanged: notifier.setPassphrase,
            onFieldSubmitted: (_) => notifier.connect(),
          ),
          SizedBox(height: sectionSpacing),
        ],

        // --- Connect button ---
        SizedBox(
          height: isSmallScreen ? 52 : 56,
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

  Widget _errorBanner(
      ThemeData theme, WifiSetupState state, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: isSmallScreen ? 22 : 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.error!,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontSize: isSmallScreen ? 13 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

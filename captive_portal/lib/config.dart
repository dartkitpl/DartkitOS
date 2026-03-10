/// App-wide configuration sourced from compile-time dart-defines.
///
/// Pass values at build time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.42.1
///   flutter build web --dart-define=API_BASE_URL=http://192.168.42.1
///
/// In production the captive portal is served by wifi-connect on the same
/// origin, so [apiBaseUrl] defaults to '' (relative URLs).
class AppConfig {
  /// Base URL for the wifi-connect HTTP API.
  ///
  /// - Production (served by wifi-connect): leave empty (same origin).
  /// - Local development: pass e.g. `http://192.168.42.1` or
  ///   `http://localhost:8080` via `--dart-define=API_BASE_URL=…`.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
}

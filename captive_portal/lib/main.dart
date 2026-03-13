import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/wifi_setup_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay styles for mobile platforms
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    // Allow both orientations for tablets
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  runApp(const ProviderScope(child: CaptivePortalApp()));
}

class CaptivePortalApp extends StatelessWidget {
  const CaptivePortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wi-Fi Setup',
      debugShowCheckedModeBanner: false,
      // Disable scrolling physics that can interfere with captive portal webview
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        // Enable touch scrolling on all platforms
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Improve touch target sizes for mobile
        visualDensity: VisualDensity.standard,
        // Ensure adequate tap target sizes for accessibility
        materialTapTargetSize: MaterialTapTargetSize.padded,
        // Input decoration theme for better mobile UX
        inputDecorationTheme: const InputDecorationTheme(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(),
        ),
        // Larger touch targets for buttons
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const WifiSetupWidget(),
    );
  }
}

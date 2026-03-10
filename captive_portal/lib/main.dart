import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/wifi_setup_widget.dart';

void main() {
  runApp(const ProviderScope(child: CaptivePortalApp()));
}

class CaptivePortalApp extends StatelessWidget {
  const CaptivePortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wi-Fi Setup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const WifiSetupWidget(),
    );
  }
}

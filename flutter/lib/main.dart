import 'package:flutter/material.dart';

import 'store.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JisoxmaoApp());
}

class JisoxmaoApp extends StatefulWidget {
  const JisoxmaoApp({super.key});

  @override
  State<JisoxmaoApp> createState() => _JisoxmaoAppState();
}

class _JisoxmaoAppState extends State<JisoxmaoApp> with WidgetsBindingObserver {
  final store = Store();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '极速熊猫',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: accent, primary: primary),
      ),
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) => AppShell(store: store),
      ),
    );
  }
}

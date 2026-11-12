import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'usage_store.dart';
import 'views.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(panelWidth, 260),
      titleBarStyle: TitleBarStyle.hidden,
      skipTaskbar: true,
      alwaysOnTop: true,
    ),
    () async {
      await windowManager.setResizable(false);
      await windowManager.hide();
    },
  );
  runApp(const ClaudeBarApp());
}

class ClaudeBarApp extends StatefulWidget {
  const ClaudeBarApp({super.key});

  @override
  State<ClaudeBarApp> createState() => _ClaudeBarAppState();
}

class _ClaudeBarAppState extends State<ClaudeBarApp> with TrayListener, WindowListener {
  final _store = UsageStore();
  final _panelKey = GlobalKey();
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    _store.addListener(_syncTray);
    _setupTray();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _store.dispose();
    super.dispose();
  }

  Future<void> _setupTray() async {
    await trayManager.setIcon('assets/tray_icon.png', isTemplate: true);
    await _syncTray();
  }

  Future<void> _syncTray() =>
      trayManager.setTitle(menuBarTitle(_store.snapshot, hasError: _store.error != null));

  @override
  void onTrayIconMouseDown() => _togglePanel();

  @override
  void onWindowBlur() => windowManager.hide();

  Future<void> _togglePanel() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
      return;
    }
    await _fitToContent();
    await _positionUnderTray();
    await windowManager.show();
    await windowManager.focus();
    _store.refresh();
  }

  Future<void> _positionUnderTray() async {
    final bounds = await trayManager.getBounds();
    if (bounds == null) return;
    final size = await windowManager.getSize();
    final x = bounds.center.dx - size.width / 2;
    await windowManager.setPosition(Offset(x < 8 ? 8 : x, bounds.bottom + 4));
  }

  /// Resizes the window to the panel's natural height (content changes with error/empty states).
  Future<void> _fitToContent() async {
    final size = _panelKey.currentContext?.size;
    if (size == null || size == _lastSize) return;
    _lastSize = size;
    await windowManager.setSize(size);
  }

  @override
  Widget build(BuildContext context) {
    // The panel's height changes with its content; keep the window in step with it.
    SchedulerBinding.instance.addPostFrameCallback((_) => _fitToContent());

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: Colors.deepOrange, brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: _store,
          builder: (context, _) => Align(
            alignment: Alignment.topLeft,
            child: UsagePanel(key: _panelKey, store: _store, onQuit: () => exit(0)),
          ),
        ),
      ),
    );
  }
}

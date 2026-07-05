import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/strings_ko.dart';
import 'core/theme.dart';
import 'features/capture/kakao_capture_sync.dart';

class CheckShippingApp extends ConsumerStatefulWidget {
  const CheckShippingApp({super.key});

  @override
  ConsumerState<CheckShippingApp> createState() => _CheckShippingAppState();
}

class _CheckShippingAppState extends ConsumerState<CheckShippingApp>
    with WidgetsBindingObserver {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLatestCapture());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncLatestCapture();
    }
  }

  Future<void> _syncLatestCapture() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await ref.read(kakaoCaptureSyncProvider).syncLatest();
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: StringsKo.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

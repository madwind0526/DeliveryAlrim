import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/app_background_bridge.dart';
import 'core/responsive_text_policy.dart';
import 'core/strings_ko.dart';
import 'core/theme.dart';
import 'core/theme_preference.dart';
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
    AppBackgroundBridge.setGoHomeHandler(() async {
      ref.read(routerProvider).go('/');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLatestCapture());
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await ref.read(themeModeStoreProvider).read();
    ref.read(themeModeNotifierProvider).value = mode;
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
      await ref
          .read(kakaoCaptureSyncProvider)
          .syncLatest(rescanActiveNotifications: true);
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeModeNotifier = ref.watch(themeModeNotifierProvider);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp.router(
          title: StringsKo.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          routerConfig: router,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: ResponsiveTextPolicy.scalerFor(media),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}

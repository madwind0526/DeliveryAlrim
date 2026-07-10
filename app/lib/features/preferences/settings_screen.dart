import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_background_button.dart';
import '../../core/constants/couriers.dart';
import '../../core/courier_registry.dart';
import '../../core/providers.dart';
import '../../core/strings_ko.dart';
import '../../core/theme_preference.dart';
import '../capture/kakao_capture_sync.dart';
import '../capture/quarantine_store.dart';
import '../debug/capture_test_runner.dart';
import '../debug/capture_test_samples.dart';
import '../tracking/tracking_api_settings.dart';
import 'android_settings_bridge.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  final _androidSettings = AndroidSettingsBridge();

  bool _notificationAccess = false;
  bool _accessibilityAccess = false;
  bool _openingSettings = false;
  bool _sendingTest = false;
  bool _syncingKakao = false;
  bool _rescanningNotifications = false;
  String _mode = StringsKo.settingModeLocal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocalPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocalPermissions();
    }
  }

  Future<void> _refreshLocalPermissions() async {
    final state = await _androidSettings.readState();
    if (!mounted) return;
    setState(() {
      _notificationAccess = state.notificationAccess;
      _accessibilityAccess = state.accessibilityAccess;
    });
  }

  Future<void> _openSystemSettings(Future<bool> Function() open) async {
    if (_openingSettings) return;
    setState(() => _openingSettings = true);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await open();
    if (!mounted) return;
    setState(() => _openingSettings = false);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text(StringsKo.settingOpenSettingsFailed)),
      );
    }
  }

  Future<void> _sendTest(CaptureTestSample sample) async {
    if (_sendingTest) return;
    setState(() => _sendingTest = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await ref.read(captureTestRunnerProvider).send(sample);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcome.result.matched
                ? StringsKo.testSendRegistered
                : StringsKo.testSendRejected,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  Future<void> _syncKakao() async {
    if (_syncingKakao) return;
    setState(() => _syncingKakao = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final synced = await ref.read(kakaoCaptureSyncProvider).syncLatest();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            synced ? StringsKo.userKakaoSyncDone : StringsKo.userKakaoSyncEmpty,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncingKakao = false);
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    ref.read(themeModeNotifierProvider).value = mode;
    await ref.read(themeModeStoreProvider).write(mode);
  }

  Future<void> _rescanActiveNotifications() async {
    if (_rescanningNotifications) return;
    setState(() => _rescanningNotifications = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final synced = await ref
          .read(kakaoCaptureSyncProvider)
          .syncLatest(rescanActiveNotifications: true);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            synced ? StringsKo.userKakaoSyncDone : StringsKo.userKakaoSyncEmpty,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _rescanningNotifications = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = kDebugMode ? _mode : StringsKo.settingModeLocal;
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringsKo.settingTitle),
        actions: const [AppBackgroundButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (kDebugMode) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: StringsKo.settingModeLocal,
                  label: Text(StringsKo.settingModeLocal),
                  icon: Icon(Icons.storage),
                ),
                ButtonSegment(
                  value: StringsKo.settingModeDebug,
                  label: Text(StringsKo.settingModeDebug),
                  icon: Icon(Icons.science_outlined),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (value) => setState(() {
                _mode = value.single;
              }),
            ),
            const SizedBox(height: 24),
          ],
          if (mode == StringsKo.settingModeLocal)
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ref.watch(themeModeNotifierProvider),
              builder: (context, themeMode, _) => _LocalSettingsSection(
                themeMode: themeMode,
                onThemeModeChanged: _setThemeMode,
                notificationAccess: _notificationAccess,
                accessibilityAccess: _accessibilityAccess,
                openingSettings: _openingSettings,
                onOpenNotificationSettings: () => _openSystemSettings(
                  _androidSettings.openNotificationAccessSettings,
                ),
                onOpenAccessibilitySettings: () => _openSystemSettings(
                  _androidSettings.openAccessibilitySettings,
                ),
              ),
            )
          else
            _TestSettingsSection(
              sendingTest: _sendingTest,
              syncingKakao: _syncingKakao,
              rescanningNotifications: _rescanningNotifications,
              onSendGmailTest: () => _sendTest(CaptureTestSamples.gmail),
              onSendSmsTest: () => _sendTest(CaptureTestSamples.sms),
              onSyncKakao: _syncKakao,
              onRescanNotifications: _rescanActiveNotifications,
            ),
        ],
      ),
    );
  }
}

class _LocalSettingsSection extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool notificationAccess;
  final bool accessibilityAccess;
  final bool openingSettings;
  final VoidCallback onOpenNotificationSettings;
  final VoidCallback onOpenAccessibilitySettings;

  const _LocalSettingsSection({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.notificationAccess,
    required this.accessibilityAccess,
    required this.openingSettings,
    required this.onOpenNotificationSettings,
    required this.onOpenAccessibilitySettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Theme'),
          trailing: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 18),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 18),
                label: Text('Dark'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (value) => onThemeModeChanged(value.single),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ),
        const SizedBox(height: 16),
        _SystemPermissionTile(
          title: StringsKo.settingNotifications,
          value: notificationAccess,
          icon: Icons.notifications_active_outlined,
          hint: StringsKo.settingNotificationSystemHint,
          openingSettings: openingSettings,
          onOpenSettings: onOpenNotificationSettings,
        ),
        const SizedBox(height: 8),
        _SystemPermissionTile(
          title: StringsKo.settingAccessibility,
          value: accessibilityAccess,
          icon: Icons.accessibility_new_outlined,
          hint: StringsKo.settingAccessibilitySystemHint,
          openingSettings: openingSettings,
          onOpenSettings: onOpenAccessibilitySettings,
        ),
        const SizedBox(height: 8),
        const _QuarantineTile(),
        const SizedBox(height: 20),
        const _TrackingApiSection(),
        const SizedBox(height: 20),
        const _CourierManagementSection(),
      ],
    );
  }
}

class _QuarantineTile extends ConsumerWidget {
  const _QuarantineTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(quarantineCountProvider)
        .maybeWhen(data: (v) => v, orElse: () => 0);
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        Icons.gpp_maybe_outlined,
        color: count > 0 ? colors.error : null,
      ),
      title: const Text(StringsKo.quarantineTitle),
      subtitle: const Text(StringsKo.quarantineSettingHint),
      trailing: count > 0
          ? Badge(label: Text('$count'), backgroundColor: colors.error)
          : const Icon(Icons.chevron_right),
      onTap: () => context.push('/quarantine'),
    );
  }
}

class _TrackingApiSection extends ConsumerStatefulWidget {
  const _TrackingApiSection();

  @override
  ConsumerState<_TrackingApiSection> createState() =>
      _TrackingApiSectionState();
}

class _TrackingApiSectionState extends ConsumerState<_TrackingApiSection> {
  final _controller = TextEditingController();
  bool _hasKey = false;
  int _usedToday = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await ref.read(sweettrackerKeyStoreProvider).read();
    final used = await ref.read(trackingQuotaStoreProvider).usedToday();
    if (!mounted) return;
    setState(() {
      _hasKey = key != null;
      _usedToday = used;
    });
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(sweettrackerKeyStoreProvider).write(key);
    _controller.clear();
    if (!mounted) return;
    setState(() => _hasKey = true);
    messenger.showSnackBar(
      const SnackBar(content: Text(StringsKo.trackingApiKeySaved)),
    );
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(sweettrackerKeyStoreProvider).delete();
    if (!mounted) return;
    setState(() => _hasKey = false);
    messenger.showSnackBar(
      const SnackBar(content: Text(StringsKo.trackingApiKeyDeleted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          StringsKo.trackingApiSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          StringsKo.trackingApiHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              _hasKey ? Icons.key : Icons.key_off_outlined,
              size: 18,
              color: _hasKey ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              _hasKey
                  ? StringsKo.trackingApiKeyRegistered
                  : StringsKo.trackingApiKeyMissing,
            ),
            if (_hasKey) ...[
              const SizedBox(width: 12),
              Text(
                '${StringsKo.trackingApiUsageToday}: $_usedToday/'
                '${DailyQuotaStore.defaultDailyLimit}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: StringsKo.trackingApiKeyInputHint,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _save, icon: const Icon(Icons.save_outlined)),
            if (_hasKey)
              IconButton(
                tooltip: StringsKo.userCredentialDelete,
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ],
    );
  }
}

class _CourierManagementSection extends ConsumerStatefulWidget {
  const _CourierManagementSection();

  @override
  ConsumerState<_CourierManagementSection> createState() =>
      _CourierManagementSectionState();
}

class _CourierManagementSectionState
    extends ConsumerState<_CourierManagementSection> {
  final _controller = TextEditingController();
  List<String>? _names;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final registry = ref.read(courierRegistryProvider);
    var names = await registry.readNames();

    // Reconcile: a courier already used by an existing parcel (e.g. one
    // removed from this list after data was captured under it, or seeded
    // by a test sample) would otherwise be unselectable/undetectable going
    // forward, so add it back automatically.
    final parcels = await ref.read(parcelRepositoryProvider).watchAll().first;
    final usedNames = parcels
        .map((p) => Couriers.byCode(p.courierCode)?.nameKo ?? p.courierCode)
        .toSet();
    final missing = usedNames.difference(names.toSet());
    for (final name in missing) {
      names = await registry.addName(name);
    }
    if (missing.isNotEmpty) {
      ref.invalidate(courierListProvider);
    }

    if (!mounted) return;
    setState(() => _names = names);
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final updated = await ref.read(courierRegistryProvider).addName(name);
    _controller.clear();
    ref.invalidate(courierListProvider);
    if (!mounted) return;
    setState(() => _names = updated);
  }

  Future<void> _remove(String name) async {
    final updated = await ref.read(courierRegistryProvider).removeName(name);
    ref.invalidate(courierListProvider);
    if (!mounted) return;
    setState(() => _names = updated);
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          StringsKo.settingCourierList,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          StringsKo.settingCourierHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (names == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (names.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              StringsKo.settingCourierEmpty,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in names)
                InputChip(label: Text(name), onDeleted: () => _remove(name)),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: StringsKo.settingCourierAddHint,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
          ],
        ),
      ],
    );
  }
}

class _SystemPermissionTile extends StatelessWidget {
  final String title;
  final bool value;
  final IconData icon;
  final String hint;
  final bool openingSettings;
  final VoidCallback onOpenSettings;

  const _SystemPermissionTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.hint,
    required this.openingSettings,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return SwitchListTile(
      value: value,
      onChanged: openingSettings ? null : (_) => onOpenSettings(),
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value
                  ? StringsKo.settingPermissionOn
                  : StringsKo.settingPermissionOff,
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestSettingsSection extends StatelessWidget {
  final bool sendingTest;
  final bool syncingKakao;
  final bool rescanningNotifications;
  final VoidCallback onSendGmailTest;
  final VoidCallback onSendSmsTest;
  final VoidCallback onSyncKakao;
  final VoidCallback onRescanNotifications;

  const _TestSettingsSection({
    required this.sendingTest,
    required this.syncingKakao,
    required this.rescanningNotifications,
    required this.onSendGmailTest,
    required this.onSendSmsTest,
    required this.onSyncKakao,
    required this.onRescanNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          StringsKo.settingTestSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: sendingTest ? null : onSendGmailTest,
            icon: const Icon(Icons.mail_outline),
            label: const Text(StringsKo.sendGmailTest),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: sendingTest ? null : onSendSmsTest,
            icon: const Icon(Icons.sms_outlined),
            label: const Text(StringsKo.sendSmsTest),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: syncingKakao ? null : onSyncKakao,
            icon: syncingKakao
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text(StringsKo.userKakaoSync),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: rescanningNotifications ? null : onRescanNotifications,
            icon: rescanningNotifications
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.notifications_active_outlined),
            label: const Text(StringsKo.activeNotificationRescan),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/debug/replay'),
            icon: const Icon(Icons.science_outlined),
            label: const Text(StringsKo.replayTitle),
          ),
        ),
      ],
    );
  }
}

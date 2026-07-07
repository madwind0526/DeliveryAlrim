import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings_ko.dart';
import '../capture/kakao_capture_sync.dart';
import '../debug/capture_test_runner.dart';
import '../debug/capture_test_samples.dart';
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
      appBar: AppBar(title: const Text(StringsKo.settingTitle)),
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
            const SizedBox(height: 12),
          ],
          if (mode == StringsKo.settingModeLocal)
            _LocalSettingsSection(
              notificationAccess: _notificationAccess,
              accessibilityAccess: _accessibilityAccess,
              openingSettings: _openingSettings,
              onOpenNotificationSettings: () => _openSystemSettings(
                _androidSettings.openNotificationAccessSettings,
              ),
              onOpenAccessibilitySettings: () => _openSystemSettings(
                _androidSettings.openAccessibilitySettings,
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
  final bool notificationAccess;
  final bool accessibilityAccess;
  final bool openingSettings;
  final VoidCallback onOpenNotificationSettings;
  final VoidCallback onOpenAccessibilitySettings;

  const _LocalSettingsSection({
    required this.notificationAccess,
    required this.accessibilityAccess,
    required this.openingSettings,
    required this.onOpenNotificationSettings,
    required this.onOpenAccessibilitySettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: sendingTest ? null : onSendGmailTest,
              icon: const Icon(Icons.mail_outline),
              label: const Text(StringsKo.sendGmailTest),
            ),
            FilledButton.tonalIcon(
              onPressed: sendingTest ? null : onSendSmsTest,
              icon: const Icon(Icons.sms_outlined),
              label: const Text(StringsKo.sendSmsTest),
            ),
            FilledButton.tonalIcon(
              onPressed: syncingKakao ? null : onSyncKakao,
              icon: syncingKakao
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text(StringsKo.userKakaoSync),
            ),
            FilledButton.tonalIcon(
              onPressed: rescanningNotifications ? null : onRescanNotifications,
              icon: rescanningNotifications
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined),
              label: const Text(StringsKo.activeNotificationRescan),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/debug/replay'),
              icon: const Icon(Icons.science_outlined),
              label: const Text(StringsKo.replayTitle),
            ),
          ],
        ),
      ],
    );
  }
}

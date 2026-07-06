import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings_ko.dart';
import '../capture/kakao_capture_sync.dart';
import '../debug/capture_test_runner.dart';
import '../debug/capture_test_samples.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;
  bool _accessibility = true;
  bool _sendingTest = false;
  bool _syncingKakao = false;
  String _mode = StringsKo.settingModeLocal;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(StringsKo.settingTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            selected: {_mode},
            onSelectionChanged: (value) => setState(() {
              _mode = value.single;
            }),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text(StringsKo.settingNotifications),
            value: _notifications,
            onChanged: (value) => setState(() => _notifications = value),
          ),
          SwitchListTile(
            title: const Text(StringsKo.settingAccessibility),
            value: _accessibility,
            onChanged: (value) => setState(() => _accessibility = value),
          ),
          const SizedBox(height: 12),
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
                onPressed: _sendingTest
                    ? null
                    : () => _sendTest(CaptureTestSamples.gmail),
                icon: const Icon(Icons.mail_outline),
                label: const Text(StringsKo.sendGmailTest),
              ),
              FilledButton.tonalIcon(
                onPressed: _sendingTest
                    ? null
                    : () => _sendTest(CaptureTestSamples.sms),
                icon: const Icon(Icons.sms_outlined),
                label: const Text(StringsKo.sendSmsTest),
              ),
              FilledButton.tonalIcon(
                onPressed: _syncingKakao ? null : _syncKakao,
                icon: _syncingKakao
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: const Text(StringsKo.userKakaoSync),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/debug/replay'),
                icon: const Icon(Icons.science_outlined),
                label: const Text(StringsKo.replayTitle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

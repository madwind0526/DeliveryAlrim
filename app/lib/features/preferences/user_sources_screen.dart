import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive_text.dart';
import '../../core/strings_ko.dart';
import '../capture/kakao_capture_sync.dart';
import '../debug/capture_test_runner.dart';
import '../debug/capture_test_samples.dart';

class UserSourcesScreen extends ConsumerStatefulWidget {
  const UserSourcesScreen({super.key});

  @override
  ConsumerState<UserSourcesScreen> createState() => _UserSourcesScreenState();
}

class _UserSourcesScreenState extends ConsumerState<UserSourcesScreen> {
  bool _emailEnabled = false;
  bool _smsEnabled = false;
  bool _kakaoEnabled = true;
  bool _secureStorage = true;
  bool _syncingKakao = false;
  bool _sendingTest = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AdaptiveText(StringsKo.userTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: StringsKo.userEmailSection,
            icon: Icons.mail_outline,
            actionLabel: StringsKo.addSource,
            onPressed: () {},
          ),
          _SwitchRow(
            label: 'Gmail',
            value: _emailEnabled,
            onChanged: (value) => setState(() => _emailEnabled = value),
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: StringsKo.userSmsSection,
            icon: Icons.sms_outlined,
            actionLabel: StringsKo.addSource,
            onPressed: () {},
          ),
          _SwitchRow(
            label: 'SMS',
            value: _smsEnabled,
            onChanged: (value) => setState(() => _smsEnabled = value),
          ),
          _SourceTestPanel(
            sending: _sendingTest,
            onSendGmail: () => _sendTest(CaptureTestSamples.gmail),
            onSendSms: () => _sendTest(CaptureTestSamples.sms),
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: StringsKo.userSnsSection,
            icon: Icons.chat_bubble_outline,
            actionLabel: StringsKo.addSource,
            onPressed: () {},
          ),
          _SwitchRow(
            label: '카카오톡',
            value: _kakaoEnabled,
            onChanged: (value) => setState(() => _kakaoEnabled = value),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _syncingKakao || !_kakaoEnabled ? null : _syncKakao,
              icon: _syncingKakao
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const AdaptiveText(StringsKo.userKakaoSync),
            ),
          ),
          _SwitchRow(
            label: StringsKo.userSecureStorage,
            value: _secureStorage,
            onChanged: (value) => setState(() => _secureStorage = value),
          ),
        ],
      ),
    );
  }
}

class _SourceTestPanel extends StatelessWidget {
  final bool sending;
  final VoidCallback onSendGmail;
  final VoidCallback onSendSms;

  const _SourceTestPanel({
    required this.sending,
    required this.onSendGmail,
    required this.onSendSms,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: sending ? null : onSendGmail,
            icon: const Icon(Icons.mail_outline),
            label: const AdaptiveText(StringsKo.sendGmailTest),
          ),
          OutlinedButton.icon(
            onPressed: sending ? null : onSendSms,
            icon: const Icon(Icons.sms_outlined),
            label: const AdaptiveText(StringsKo.sendSmsTest),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: AdaptiveText(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 16),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onPressed;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: AdaptiveText(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: AdaptiveText(actionLabel),
          ),
        ],
      ),
    );
  }
}

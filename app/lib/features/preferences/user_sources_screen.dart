import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive_text.dart';
import '../../core/strings_ko.dart';
import '../capture/kakao_capture_sync.dart';

class UserSourcesScreen extends ConsumerStatefulWidget {
  const UserSourcesScreen({super.key});

  @override
  ConsumerState<UserSourcesScreen> createState() => _UserSourcesScreenState();
}

class _UserSourcesScreenState extends ConsumerState<UserSourcesScreen> {
  bool _emailEnabled = false;
  bool _kakaoEnabled = true;
  bool _secureStorage = true;
  bool _syncingKakao = false;

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
      appBar: AppBar(title: const AdaptiveText(StringsKo.userTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: StringsKo.userEmailSection,
            actionLabel: StringsKo.addSource,
            onPressed: () {},
          ),
          _SwitchRow(
            label: 'Gmail',
            status: _emailEnabled
                ? StringsKo.sourceEnabled
                : StringsKo.sourceDisabled,
            value: _emailEnabled,
            onChanged: (value) => setState(() => _emailEnabled = value),
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: StringsKo.userSnsSection,
            actionLabel: StringsKo.addSource,
            onPressed: () {},
          ),
          _SwitchRow(
            label: '카카오톡',
            status: _kakaoEnabled
                ? StringsKo.sourceEnabled
                : StringsKo.sourceDisabled,
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

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? status;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    this.status,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = status == null ? label : '$label · $status';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: AdaptiveText(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: status == StringsKo.sourceDisabled
                    ? colors.onSurfaceVariant
                    : null,
              ),
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
  final String actionLabel;
  final VoidCallback onPressed;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AdaptiveText(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: AdaptiveText(actionLabel),
        ),
      ],
    );
  }
}

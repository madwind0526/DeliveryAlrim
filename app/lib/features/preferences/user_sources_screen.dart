import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive_text.dart';
import '../../core/secure_credentials.dart';
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
  bool _otherEmailEnabled = false;
  bool _otherEmailVisible = false;
  bool _smsEnabled = false;
  bool _smsVisible = false;
  bool _kakaoEnabled = true;
  bool _telegramEnabled = false;
  bool _telegramVisible = false;
  bool _whatsappEnabled = false;
  bool _whatsappVisible = false;
  bool _syncingKakao = false;
  bool _sendingTest = false;
  String _otherEmailLabel = '기타 이메일';
  Set<CredentialSource> _storedCredentials = {};

  @override
  void initState() {
    super.initState();
    _loadCredentialStates();
  }

  Future<void> _loadCredentialStates() async {
    final store = ref.read(credentialStoreProvider);
    final labelStore = ref.read(sourceLabelStoreProvider);
    final entries = await Future.wait([
      store.has(CredentialSource.gmail),
      store.has(CredentialSource.otherEmail),
      store.has(CredentialSource.kakao),
      store.has(CredentialSource.telegram),
      store.has(CredentialSource.whatsapp),
    ]);
    final otherEmailLabel = await labelStore.read(CredentialSource.otherEmail);
    if (!mounted) return;
    setState(() {
      _storedCredentials = {
        if (entries[0]) CredentialSource.gmail,
        if (entries[1]) CredentialSource.otherEmail,
        if (entries[2]) CredentialSource.kakao,
        if (entries[3]) CredentialSource.telegram,
        if (entries[4]) CredentialSource.whatsapp,
      };
      _otherEmailVisible = entries[1];
      _telegramVisible = entries[3];
      _whatsappVisible = entries[4];
      _otherEmailLabel = _cleanLabel(otherEmailLabel, '기타 이메일');
    });
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

  Future<void> _openCredentialDialog(
    CredentialSource source,
    String label,
  ) async {
    final store = ref.read(credentialStoreProvider);
    final existing = await store.read(source);
    if (!mounted) return;

    final result = await showDialog<_CredentialDialogResult>(
      context: context,
      builder: (context) =>
          _CredentialDialog(sourceLabel: label, existing: existing),
    );
    if (result == null) return;

    if (result.delete) {
      await store.delete(source);
      await _loadCredentialStates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(StringsKo.userCredentialDeletedSnack)),
      );
      return;
    }

    await store.write(
      source,
      SourceCredential(account: result.account, secret: result.secret),
    );
    await _loadCredentialStates();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(StringsKo.userCredentialSavedSnack)),
    );
  }

  String _cleanLabel(String? value, String fallback) {
    final label = value?.trim();
    return label == null || label.isEmpty ? fallback : label;
  }

  Future<void> _openAddSourceDialog(List<_SourceOption> options) async {
    final result = await showDialog<_AddSourceDialogResult>(
      context: context,
      builder: (context) => _AddSourceDialog(options: options),
    );
    if (result == null) return;
    if (!mounted) return;

    setState(result.option.enable);
    final displayLabel = result.displayLabel;
    final labelSource = result.option.labelSource;
    if (displayLabel != null && labelSource != null) {
      await ref.read(sourceLabelStoreProvider).write(labelSource, displayLabel);
      if (!mounted) return;
    }
    final credential = result.credential;
    final credentialSource = result.option.credentialSource;
    if (credential == null || credentialSource == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(StringsKo.sourceAddedSnack)));
      return;
    }

    await ref.read(credentialStoreProvider).write(credentialSource, credential);
    await _loadCredentialStates();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(StringsKo.userCredentialSavedSnack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AdaptiveText(StringsKo.userTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _CredentialNotice(),
          const SizedBox(height: 12),
          _SectionHeader(
            title: StringsKo.userEmailSection,
            icon: Icons.mail_outline,
            actionLabel: StringsKo.addSource,
            onPressed: () => _openAddSourceDialog([
              _SourceOption(
                label: 'Gmail',
                icon: Icons.mail_outline,
                credentialSource: CredentialSource.gmail,
                enable: () => _emailEnabled = true,
              ),
              _SourceOption(
                label: '기타 이메일',
                icon: Icons.alternate_email,
                credentialSource: CredentialSource.otherEmail,
                labelSource: CredentialSource.otherEmail,
                editableLabel: true,
                enable: () {
                  _otherEmailVisible = true;
                  _otherEmailEnabled = true;
                },
              ),
            ]),
          ),
          _SwitchRow(
            label: 'Gmail',
            value: _emailEnabled,
            onChanged: (value) => setState(() => _emailEnabled = value),
            credentialStored: _storedCredentials.contains(
              CredentialSource.gmail,
            ),
            onCredentialPressed: () =>
                _openCredentialDialog(CredentialSource.gmail, 'Gmail'),
          ),
          if (_otherEmailVisible)
            _SwitchRow(
              label: _otherEmailLabel,
              value: _otherEmailEnabled,
              onChanged: (value) => setState(() => _otherEmailEnabled = value),
              credentialStored: _storedCredentials.contains(
                CredentialSource.otherEmail,
              ),
              onCredentialPressed: () => _openCredentialDialog(
                CredentialSource.otherEmail,
                _otherEmailLabel,
              ),
            ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: StringsKo.userSmsSection,
            icon: Icons.sms_outlined,
            actionLabel: StringsKo.addSource,
            onPressed: () => _openAddSourceDialog([
              _SourceOption(
                label: 'SMS',
                icon: Icons.sms_outlined,
                enable: () {
                  _smsVisible = true;
                  _smsEnabled = true;
                },
              ),
            ]),
          ),
          if (_smsVisible)
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
            onPressed: () => _openAddSourceDialog([
              _SourceOption(
                label: '카카오톡',
                icon: Icons.chat_bubble_outline,
                credentialSource: CredentialSource.kakao,
                enable: () => _kakaoEnabled = true,
              ),
              _SourceOption(
                label: '텔레그램',
                icon: Icons.send_outlined,
                credentialSource: CredentialSource.telegram,
                enable: () {
                  _telegramVisible = true;
                  _telegramEnabled = true;
                },
              ),
              _SourceOption(
                label: 'WhatsApp',
                icon: Icons.forum_outlined,
                credentialSource: CredentialSource.whatsapp,
                enable: () {
                  _whatsappVisible = true;
                  _whatsappEnabled = true;
                },
              ),
            ]),
          ),
          _SwitchRow(
            label: '카카오톡',
            value: _kakaoEnabled,
            onChanged: (value) => setState(() => _kakaoEnabled = value),
            credentialStored: _storedCredentials.contains(
              CredentialSource.kakao,
            ),
            onCredentialPressed: () =>
                _openCredentialDialog(CredentialSource.kakao, '카카오톡'),
          ),
          if (_telegramVisible)
            _SwitchRow(
              label: '텔레그램',
              value: _telegramEnabled,
              onChanged: (value) => setState(() => _telegramEnabled = value),
              credentialStored: _storedCredentials.contains(
                CredentialSource.telegram,
              ),
              onCredentialPressed: () =>
                  _openCredentialDialog(CredentialSource.telegram, '텔레그램'),
            ),
          if (_whatsappVisible)
            _SwitchRow(
              label: 'WhatsApp',
              value: _whatsappEnabled,
              onChanged: (value) => setState(() => _whatsappEnabled = value),
              credentialStored: _storedCredentials.contains(
                CredentialSource.whatsapp,
              ),
              onCredentialPressed: () =>
                  _openCredentialDialog(CredentialSource.whatsapp, 'WhatsApp'),
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
        ],
      ),
    );
  }
}

class _SourceOption {
  final String label;
  final IconData icon;
  final CredentialSource? credentialSource;
  final CredentialSource? labelSource;
  final bool editableLabel;
  final VoidCallback enable;

  const _SourceOption({
    required this.label,
    required this.icon,
    required this.enable,
    this.credentialSource,
    this.labelSource,
    this.editableLabel = false,
  });
}

class _AddSourceDialogResult {
  final _SourceOption option;
  final SourceCredential? credential;
  final String? displayLabel;

  const _AddSourceDialogResult({
    required this.option,
    this.credential,
    this.displayLabel,
  });
}

class _AddSourceDialog extends StatefulWidget {
  final List<_SourceOption> options;

  const _AddSourceDialog({required this.options});

  @override
  State<_AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<_AddSourceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _accountController = TextEditingController();
  final _secretController = TextEditingController();
  late _SourceOption _selected;
  bool _secretVisible = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.options.first;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _accountController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  bool get _needsCredential => _selected.credentialSource != null;
  bool get _needsDisplayName => _selected.editableLabel;

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _AddSourceDialogResult(
        option: _selected,
        displayLabel: _needsDisplayName ? _labelController.text.trim() : null,
        credential: _needsCredential
            ? SourceCredential(
                account: _accountController.text.trim(),
                secret: _secretController.text,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxContentHeight = (media.size.height - media.viewInsets.bottom - 220)
        .clamp(220.0, 420.0);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: const AdaptiveText(StringsKo.addSourceTitle),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxContentHeight),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<_SourceOption>(
                  initialValue: _selected,
                  decoration: const InputDecoration(
                    labelText: StringsKo.channelLabel,
                  ),
                  items: [
                    for (final option in widget.options)
                      DropdownMenuItem(
                        value: option,
                        child: Row(
                          children: [
                            Icon(option.icon, size: 20),
                            const SizedBox(width: 8),
                            AdaptiveText(option.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (option) {
                    if (option == null) return;
                    setState(() {
                      _selected = option;
                      _labelController.clear();
                      _accountController.clear();
                      _secretController.clear();
                      _secretVisible = false;
                    });
                  },
                ),
                if (_needsDisplayName) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: StringsKo.sourceDisplayName,
                      hintText: StringsKo.sourceDisplayNameHint,
                    ),
                    validator: _requiredDisplayName,
                  ),
                ],
                if (_needsCredential) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountController,
                    decoration: const InputDecoration(
                      labelText: StringsKo.userCredentialAccount,
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _secretController,
                    obscureText: !_secretVisible,
                    decoration: InputDecoration(
                      labelText: StringsKo.userCredentialSecret,
                      suffixIcon: IconButton(
                        tooltip: _secretVisible
                            ? StringsKo.userCredentialHideSecret
                            : StringsKo.userCredentialShowSecret,
                        icon: Icon(
                          _secretVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() {
                          _secretVisible = !_secretVisible;
                        }),
                      ),
                    ),
                    validator: _required,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const AdaptiveText(StringsKo.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: const AdaptiveText(StringsKo.userCredentialSave),
        ),
      ],
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? StringsKo.userCredentialRequired
      : null;

  String? _requiredDisplayName(String? value) =>
      value == null || value.trim().isEmpty
      ? StringsKo.sourceDisplayNameRequired
      : null;
}

class _CredentialNotice extends StatelessWidget {
  const _CredentialNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.lock_outline, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: AdaptiveText(
            StringsKo.userSecureStorageNotice,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
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
  final bool? credentialStored;
  final VoidCallback? onCredentialPressed;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.credentialStored,
    this.onCredentialPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stored = credentialStored ?? false;
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
          if (onCredentialPressed != null) ...[
            Tooltip(
              message: stored
                  ? StringsKo.userCredentialSaved
                  : StringsKo.userCredentialMissing,
              child: IconButton(
                onPressed: onCredentialPressed,
                icon: Icon(
                  stored ? Icons.key : Icons.key_off_outlined,
                  color: stored ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CredentialDialogResult {
  final String account;
  final String secret;
  final bool delete;

  const _CredentialDialogResult.save({
    required this.account,
    required this.secret,
  }) : delete = false;

  const _CredentialDialogResult.delete()
    : account = '',
      secret = '',
      delete = true;
}

class _CredentialDialog extends StatefulWidget {
  final String sourceLabel;
  final SourceCredential? existing;

  const _CredentialDialog({required this.sourceLabel, required this.existing});

  @override
  State<_CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends State<_CredentialDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _accountController;
  late final TextEditingController _secretController;
  bool _secretVisible = false;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(
      text: widget.existing?.account ?? '',
    );
    _secretController = TextEditingController(
      text: widget.existing?.secret ?? '',
    );
  }

  @override
  void dispose() {
    _accountController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _CredentialDialogResult.save(
        account: _accountController.text.trim(),
        secret: _secretController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxContentHeight = (media.size.height - media.viewInsets.bottom - 220)
        .clamp(220.0, 420.0);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: AdaptiveText(
        '${widget.sourceLabel} ${StringsKo.userCredentialTitle}',
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxContentHeight),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _accountController,
                  decoration: const InputDecoration(
                    labelText: StringsKo.userCredentialAccount,
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _secretController,
                  obscureText: !_secretVisible,
                  decoration: InputDecoration(
                    labelText: StringsKo.userCredentialSecret,
                    suffixIcon: IconButton(
                      tooltip: _secretVisible
                          ? StringsKo.userCredentialHideSecret
                          : StringsKo.userCredentialShowSecret,
                      icon: Icon(
                        _secretVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() {
                        _secretVisible = !_secretVisible;
                      }),
                    ),
                  ),
                  validator: _required,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const _CredentialDialogResult.delete()),
            child: const AdaptiveText(StringsKo.userCredentialDelete),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const AdaptiveText(StringsKo.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: const AdaptiveText(StringsKo.userCredentialSave),
        ),
      ],
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? StringsKo.userCredentialRequired
      : null;
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

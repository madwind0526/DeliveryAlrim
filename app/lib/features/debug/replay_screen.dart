import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/couriers.dart';
import '../../core/providers.dart';
import '../../core/strings_ko.dart';
import '../capture/capture_models.dart';
import '../capture/rules_provider.dart';

/// Debug-only injection screen: paste any notification/SMS/email text,
/// run the rule engine, inspect the result, and optionally register it.
/// This is the PC-mode stand-in for the Android notification listener.
class ReplayScreen extends ConsumerStatefulWidget {
  const ReplayScreen({super.key});

  @override
  ConsumerState<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends ConsumerState<ReplayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _packageController = TextEditingController();
  final _senderController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  CaptureChannel _channel = CaptureChannel.kakao;
  RawCapture? _lastCapture;
  ParseResult? _lastResult;
  bool _registered = false;

  @override
  void dispose() {
    _packageController.dispose();
    _senderController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _runParse() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final engine = await ref.read(ruleEngineProvider.future);

    String? nullable(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final capture = RawCapture(
      channel: _channel,
      packageName: nullable(_packageController),
      sender: nullable(_senderController),
      title: nullable(_titleController),
      body: _bodyController.text,
      capturedAt: DateTime.now(),
    );
    setState(() {
      _lastCapture = capture;
      _lastResult = engine.parse(capture);
      _registered = false;
    });
  }

  Future<void> _register() async {
    final capture = _lastCapture;
    final result = _lastResult;
    if (capture == null || result == null || !result.matched) return;

    await ref
        .read(parcelRepositoryProvider)
        .upsert(
          result.parcel!.toParcel(capture),
          eventNote: '알림 주입 (${capture.channel.labelKo})',
        );

    if (!mounted) return;
    setState(() => _registered = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(StringsKo.registeredSnack)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(StringsKo.replayTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<CaptureChannel>(
                  initialValue: _channel,
                  decoration: const InputDecoration(
                    labelText: StringsKo.channelLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in CaptureChannel.values)
                      DropdownMenuItem(value: c, child: Text(c.labelKo)),
                  ],
                  onChanged: (c) => setState(() => _channel = c!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _packageController,
                        decoration: const InputDecoration(
                          labelText: StringsKo.packageNameLabel,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _senderController,
                        decoration: const InputDecoration(
                          labelText: StringsKo.senderLabel,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: StringsKo.notifTitleLabel,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: StringsKo.bodyLabel,
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 10,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? StringsKo.bodyEmpty
                      : null,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _runParse,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(StringsKo.runParse),
                ),
                if (_lastResult != null) ...[
                  const SizedBox(height: 16),
                  _ResultCard(
                    result: _lastResult!,
                    registered: _registered,
                    onRegister: _register,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ParseResult result;
  final bool registered;
  final VoidCallback onRegister;

  const _ResultCard({
    required this.result,
    required this.registered,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.matched) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cancel_outlined, color: Color(0xFFF87171)),
          title: const Text(StringsKo.parseRejected),
          subtitle: Text(result.reason!.labelKo),
        ),
      );
    }

    final p = result.parcel!;
    final courierName = Couriers.byCode(p.courierCode)?.nameKo ?? p.courierCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF4ADE80),
                ),
                const SizedBox(width: 8),
                Text(
                  StringsKo.parseMatched,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${StringsKo.matchedRuleLabel}: ${p.matchedRuleId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const Divider(),
            Text('${StringsKo.courierLabel}: $courierName'),
            Text('${StringsKo.trackingNumberLabel}: ${p.trackingNumber}'),
            Text('${StringsKo.statusLabel}: ${p.status.labelKo}'),
            if (p.productName != null)
              Text('${StringsKo.productNameLabel}: ${p.productName}'),
            if (p.mallName != null)
              Text('${StringsKo.mallNameLabel}: ${p.mallName}'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: registered ? null : onRegister,
              child: const Text(StringsKo.registerParcelButton),
            ),
          ],
        ),
      ),
    );
  }
}

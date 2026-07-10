import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/local_db/local_db.dart';
import '../../core/strings_ko.dart';
import 'capture_models.dart';
import 'quarantine_store.dart';

/// Review list for suspected-phishing captures. The body is rendered as
/// plain, non-tappable text on purpose: nothing here may open a link.
class QuarantineScreen extends ConsumerWidget {
  const QuarantineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(quarantineListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(StringsKo.quarantineTitle)),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text(StringsKo.quarantineEmpty));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const _WarningBanner(),
              const SizedBox(height: 8),
              for (final row in rows) _QuarantineCard(row: row),
            ],
          );
        },
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              StringsKo.quarantineWarning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuarantineCard extends ConsumerWidget {
  final QuarantineRow row;

  const _QuarantineCard({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final timeFmt = DateFormat('M월 d일 (E) HH:mm', 'ko');
    final channelLabel = CaptureChannel.values
        .where((c) => c.code == row.channel)
        .map((c) => c.labelKo)
        .firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      channelLabel ?? row.channel,
                      if (row.sender != null && row.sender!.isNotEmpty)
                        row.sender!,
                      timeFmt.format(row.capturedAt),
                    ].join(' · '),
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: StringsKo.quarantineDelete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref.read(quarantineStoreProvider).delete(row.id);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(StringsKo.quarantineDeleted),
                      ),
                    );
                  },
                ),
              ],
            ),
            Chip(
              label: Text(
                '${StringsKo.quarantineReasonLabel}: ${row.reason}',
                style: const TextStyle(fontSize: 12),
              ),
              visualDensity: VisualDensity.compact,
              backgroundColor: colors.errorContainer,
              labelStyle: TextStyle(color: colors.onErrorContainer),
              side: BorderSide.none,
            ),
            const SizedBox(height: 8),
            if (row.title != null && row.title!.isNotEmpty)
              Text(
                row.title!,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            // Plain Text: never linkified, never tappable.
            Text(row.body, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

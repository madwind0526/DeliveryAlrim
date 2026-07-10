import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/couriers.dart';
import '../../core/providers.dart';
import '../../core/strings_ko.dart';
import '../capture/capture_models.dart';
import '../tracking/tracking_refresh_service.dart';
import 'models/parcel.dart';
import 'models/tracking_event.dart';

final _parcelByIdProvider = StreamProvider.family<Parcel?, String>((ref, id) {
  return ref.watch(parcelRepositoryProvider).watchById(id);
});

final _eventsProvider = StreamProvider.family<List<TrackingEvent>, String>((
  ref,
  id,
) {
  return ref.watch(parcelRepositoryProvider).watchEvents(id);
});

class ParcelDetailScreen extends ConsumerWidget {
  final String parcelId;

  const ParcelDetailScreen({super.key, required this.parcelId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(StringsKo.deleteConfirmTitle),
        content: const Text(StringsKo.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(StringsKo.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(StringsKo.deleteParcel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(parcelRepositoryProvider).delete(parcelId);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelAsync = ref.watch(_parcelByIdProvider(parcelId));
    final eventsAsync = ref.watch(_eventsProvider(parcelId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(StringsKo.detailTitle),
        actions: [
          _RefreshAction(parcelId: parcelId),
          IconButton(
            tooltip: StringsKo.deleteParcel,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: parcelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (parcel) {
          if (parcel == null) {
            return const Center(child: Text(StringsKo.parcelNotFound));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(parcel: parcel),
              const SizedBox(height: 16),
              Text(
                StringsKo.timelineTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              eventsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (events) => events.isEmpty
                    ? const Text(StringsKo.noEvents)
                    : Column(
                        children: [
                          for (var i = 0; i < events.length; i++)
                            _TimelineTile(
                              event: events[i],
                              isFirst: i == 0,
                              isLast: i == events.length - 1,
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Optional Sweet Tracker one-shot query for this parcel. No API key
/// registered → snackbar pointing to Settings; the feature stays off.
class _RefreshAction extends ConsumerStatefulWidget {
  final String parcelId;

  const _RefreshAction({required this.parcelId});

  @override
  ConsumerState<_RefreshAction> createState() => _RefreshActionState();
}

class _RefreshActionState extends ConsumerState<_RefreshAction> {
  bool _busy = false;

  Future<void> _refresh() async {
    if (_busy) return;
    final parcel = ref.read(_parcelByIdProvider(widget.parcelId)).value;
    if (parcel == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(trackingRefreshServiceProvider)
          .refreshParcel(parcel);
      final text = switch (result.outcome) {
        RefreshOutcome.updated => StringsKo.trackingRefreshUpdated,
        RefreshOutcome.unchanged => StringsKo.trackingRefreshNoChange,
        RefreshOutcome.unsupported => StringsKo.trackingRefreshUnsupported,
        RefreshOutcome.alreadyDone => StringsKo.trackingRefreshAlreadyDone,
        RefreshOutcome.missingKey => StringsKo.trackingRefreshMissingKey,
        RefreshOutcome.quotaExceeded => StringsKo.trackingQuotaExceeded,
        RefreshOutcome.failed =>
          '${StringsKo.trackingRefreshFailed}: ${result.message ?? ''}',
      };
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: StringsKo.trackingRefresh,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      onPressed: _busy ? null : _refresh,
    );
  }
}

class _Header extends StatelessWidget {
  final Parcel parcel;

  const _Header({required this.parcel});

  @override
  Widget build(BuildContext context) {
    final courierName =
        Couriers.byCode(parcel.courierCode)?.nameKo ?? parcel.courierCode;
    final dateFmt = DateFormat('yyyy년 M월 d일 (E)', 'ko');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    parcel.productName ?? StringsKo.unknownProduct,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(
                    parcel.status.labelKo,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: parcel.status.color,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
            const Divider(),
            Text('${StringsKo.courierLabel}: $courierName'),
            if (!parcel.trackingNumber.startsWith('cp:'))
              Text(
                '${StringsKo.trackingNumberLabel}: ${parcel.trackingNumber}',
              ),
            if (parcel.mallName != null)
              Text('${StringsKo.mallNameLabel}: ${parcel.mallName}'),
            if (parcel.expectedArrivalDate != null)
              Text(
                '${StringsKo.expectedBadge}: ${dateFmt.format(parcel.expectedArrivalDate!)}',
              ),
            if (parcel.deliveredAt != null)
              Text(
                '${StringsKo.deliveredBadge}: ${dateFmt.format(parcel.deliveredAt!)}',
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final channel in parcel.sourceChannels)
                  Chip(
                    label: Text(
                      CaptureChannel.values
                              .where((c) => c.code == channel)
                              .map((c) => c.labelKo)
                              .firstOrNull ??
                          channel,
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final TrackingEvent event;
  final bool isFirst;
  final bool isLast;

  const _TimelineTile({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('M월 d일 (E) HH:mm', 'ko');
    final lineColor = Theme.of(context).colorScheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 8,
                  color: isFirst ? Colors.transparent : lineColor,
                ),
                Icon(Icons.circle, size: 12, color: event.status.color),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : lineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.status.labelKo,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    timeFmt.format(event.eventTime),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (event.location != null || event.description != null)
                    Text(
                      [
                        event.location,
                        event.description,
                      ].whereType<String>().join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

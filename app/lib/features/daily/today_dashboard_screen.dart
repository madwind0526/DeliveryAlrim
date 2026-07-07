import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/adaptive_text.dart';
import '../../core/constants/couriers.dart';
import '../../core/providers.dart';
import '../../core/strings_ko.dart';
import '../parcels/models/parcel.dart';
import '../parcels/widgets/parcel_status_badge.dart';

final todayParcelsProvider = StreamProvider<List<Parcel>>(
  (ref) => ref.watch(parcelRepositoryProvider).watchAll(),
);

class TodayDashboardScreen extends ConsumerWidget {
  const TodayDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelsAsync = ref.watch(todayParcelsProvider);
    return Scaffold(
      appBar: AppBar(title: const AdaptiveText(StringsKo.todaySummaryTitle)),
      body: parcelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (parcels) {
          final today = DateUtils.dateOnly(DateTime.now());
          final ordered = _ordered(parcels);
          final inTransit = _inTransit(parcels);
          final completedToday = _completedToday(parcels, today);
          final dueToday = _dueToday(parcels, today);
          final allEmpty =
              ordered.isEmpty &&
              inTransit.isEmpty &&
              completedToday.isEmpty &&
              dueToday.isEmpty;

          if (allEmpty) {
            return Center(
              child: Text(
                StringsKo.todayAllClear,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              _SummaryStrip(
                ordered: ordered.length,
                inTransit: inTransit.length,
                completedToday: completedToday.length,
                dueToday: dueToday.length,
              ),
              const SizedBox(height: 12),
              _TodaySection(
                title: StringsKo.todayOrdered,
                icon: Icons.receipt_long_outlined,
                parcels: ordered,
              ),
              _TodaySection(
                title: StringsKo.todayInTransit,
                icon: Icons.local_shipping_outlined,
                parcels: inTransit,
              ),
              _TodaySection(
                title: StringsKo.todayCompleted,
                icon: Icons.check_circle_outline,
                parcels: completedToday,
              ),
              _TodaySection(
                title: StringsKo.todayDue,
                icon: Icons.event_available_outlined,
                parcels: dueToday,
              ),
            ],
          );
        },
      ),
    );
  }

  List<Parcel> _ordered(List<Parcel> parcels) {
    return parcels
        .where(
          (p) =>
              p.status == ParcelStatus.registered ||
              p.status == ParcelStatus.preparing,
        )
        .toList()
      ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
  }

  List<Parcel> _inTransit(List<Parcel> parcels) {
    return parcels
        .where(
          (p) =>
              p.status == ParcelStatus.pickedUp ||
              p.status == ParcelStatus.inTransit,
        )
        .toList()
      ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
  }

  List<Parcel> _completedToday(List<Parcel> parcels, DateTime today) {
    return parcels.where((p) {
      if (p.status != ParcelStatus.delivered) return false;
      final delivered = p.deliveredAt;
      if (delivered == null) return false;
      return DateUtils.isSameDay(delivered, today);
    }).toList()..sort((a, b) {
      final aTime = a.deliveredAt ?? a.registeredAt;
      final bTime = b.deliveredAt ?? b.registeredAt;
      return bTime.compareTo(aTime);
    });
  }

  List<Parcel> _dueToday(List<Parcel> parcels, DateTime today) {
    return parcels.where((p) {
      if (p.status.isTerminal) return false;
      if (p.status == ParcelStatus.outForDelivery) return true;
      final expected = p.expectedArrivalDate;
      if (expected == null) return false;
      return DateUtils.isSameDay(expected, today);
    }).toList()..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
  }
}

class _SummaryStrip extends StatelessWidget {
  final int ordered;
  final int inTransit;
  final int completedToday;
  final int dueToday;

  const _SummaryStrip({
    required this.ordered,
    required this.inTransit,
    required this.completedToday,
    required this.dueToday,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: compact ? 2 : 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: compact ? 2.0 : 1.6,
      children: [
        _SummaryItem(label: StringsKo.todayOrdered, value: ordered),
        _SummaryItem(label: StringsKo.todayInTransit, value: inTransit),
        _SummaryItem(label: StringsKo.todayCompleted, value: completedToday),
        _SummaryItem(label: StringsKo.todayDue, value: dueToday),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdaptiveText(
                '$value',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              AdaptiveText(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Parcel> parcels;

  const _TodaySection({
    required this.title,
    required this.icon,
    required this.parcels,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: AdaptiveText(
                  '$title ${parcels.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (parcels.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                StringsKo.todaySectionEmpty,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final parcel in parcels) _TodayParcelTile(parcel: parcel),
        ],
      ),
    );
  }
}

class _TodayParcelTile extends StatelessWidget {
  final Parcel parcel;

  const _TodayParcelTile({required this.parcel});

  @override
  Widget build(BuildContext context) {
    final courierName =
        Couriers.byCode(parcel.courierCode)?.nameKo ?? parcel.courierCode;
    return Card(
      child: ListTile(
        onTap: () => context.push('/parcel/${parcel.id}'),
        title: AdaptiveText(parcel.productName ?? StringsKo.unknownProduct),
        subtitle: AdaptiveText(
          [
            courierName,
            if (parcel.mallName != null) parcel.mallName!,
            if (!parcel.trackingNumber.startsWith('cp:')) parcel.trackingNumber,
          ].join(' · '),
        ),
        trailing: ParcelStatusBadge(status: parcel.status),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_background_button.dart';
import '../../core/adaptive_text.dart';
import '../../core/providers.dart';
import '../../core/strings_ko.dart';
import '../parcels/models/parcel.dart';
import '../parcels/widgets/parcel_summary_section.dart';

class TodayDashboardScreen extends ConsumerWidget {
  const TodayDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelsAsync = ref.watch(allParcelsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const AdaptiveText(StringsKo.todaySummaryTitle),
        actions: const [AppBackgroundButton()],
      ),
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
              ParcelSummaryStrip(
                items: [
                  ParcelSummaryItem(
                    label: StringsKo.todayOrdered,
                    value: ordered.length,
                  ),
                  ParcelSummaryItem(
                    label: StringsKo.todayInTransit,
                    value: inTransit.length,
                  ),
                  ParcelSummaryItem(
                    label: StringsKo.todayCompleted,
                    value: completedToday.length,
                  ),
                  ParcelSummaryItem(
                    label: StringsKo.todayDue,
                    value: dueToday.length,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ParcelSection(
                title: StringsKo.todayOrdered,
                icon: Icons.receipt_long_outlined,
                parcels: ordered,
              ),
              ParcelSection(
                title: StringsKo.todayInTransit,
                icon: Icons.local_shipping_outlined,
                parcels: inTransit,
              ),
              ParcelSection(
                title: StringsKo.todayCompleted,
                icon: Icons.check_circle_outline,
                parcels: completedToday,
              ),
              ParcelSection(
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/app_background_button.dart';
import '../../core/constants/couriers.dart';
import '../../core/providers.dart';
import '../../core/strings_ko.dart';
import '../parcels/models/parcel.dart';
import '../parcels/widgets/parcel_status_badge.dart';

/// Day (date-only) → parcels arriving or delivered that day.
/// Done parcels count on deliveredAt; active ones on expectedArrivalDate
/// when known, falling back to registeredAt so an in-transit parcel with
/// no arrival estimate yet still shows up somewhere instead of vanishing.
final parcelsByDayProvider = Provider<AsyncValue<Map<DateTime, List<Parcel>>>>((
  ref,
) {
  return ref.watch(allParcelsProvider).whenData((parcels) {
    final map = <DateTime, List<Parcel>>{};
    for (final p in parcels) {
      final date = p.deliveredAt ?? p.expectedArrivalDate ?? p.registeredAt;
      final day = DateTime(date.year, date.month, date.day);
      (map[day] ??= []).add(p);
    }
    return map;
  });
});

class CalendarScreen extends ConsumerStatefulWidget {
  final CalendarFormat initialFormat;
  final String title;

  const CalendarScreen.monthly({super.key})
    : initialFormat = CalendarFormat.month,
      title = StringsKo.monthlyTitle;

  const CalendarScreen.daily({super.key})
    : initialFormat = CalendarFormat.week,
      title = StringsKo.dailyTitle;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  late CalendarFormat _format = widget.initialFormat;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final byDayAsync = ref.watch(parcelsByDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: const [AppBackgroundButton()],
      ),
      body: byDayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (byDay) {
          final selected = byDay[_dateOnly(_selectedDay)] ?? const <Parcel>[];
          return Column(
            children: [
              TableCalendar<Parcel>(
                locale: 'ko',
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 90)),
                focusedDay: _focusedDay,
                calendarFormat: _format,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                eventLoader: (day) => byDay[_dateOnly(day)] ?? const [],
                startingDayOfWeek: StartingDayOfWeek.sunday,
                availableCalendarFormats: const {
                  CalendarFormat.month: '월',
                  CalendarFormat.week: '주',
                  CalendarFormat.twoWeeks: '2주',
                },
                headerStyle: const HeaderStyle(titleCentered: true),
                calendarStyle: CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                onFormatChanged: (format) => setState(() {
                  _format = format;
                }),
              ),
              const Divider(height: 1),
              Expanded(
                child: selected.isEmpty
                    ? const Center(child: Text(StringsKo.dayEmpty))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: selected.length,
                        itemBuilder: (context, i) =>
                            _DayParcelTile(parcel: selected[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayParcelTile extends StatelessWidget {
  final Parcel parcel;

  const _DayParcelTile({required this.parcel});

  @override
  Widget build(BuildContext context) {
    final courierName =
        Couriers.byCode(parcel.courierCode)?.nameKo ?? parcel.courierCode;
    final badge = parcel.deliveredAt != null
        ? StringsKo.deliveredBadge
        : StringsKo.expectedBadge;

    return Card(
      child: ListTile(
        title: Text(
          parcel.productName ?? StringsKo.unknownProduct,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('$courierName · $badge'),
        trailing: ParcelStatusBadge(status: parcel.status),
        onTap: () => context.push('/parcel/${parcel.id}'),
      ),
    );
  }
}

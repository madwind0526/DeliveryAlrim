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
import 'parcel_day_index.dart';

/// Day (date-only) → parcels visible that day with their as-of-that-day
/// status, reconstructed from the tracking-event log. Active parcels carry
/// forward every day until they finish, and past days keep the status they
/// had back then (see buildParcelDayIndex).
final parcelsByDayProvider =
    Provider<AsyncValue<Map<DateTime, List<DayParcelEntry>>>>((ref) {
      final parcelsAsync = ref.watch(allParcelsProvider);
      final eventsAsync = ref.watch(allTrackingEventsProvider);
      return switch ((parcelsAsync, eventsAsync)) {
        (AsyncData(value: final parcels), AsyncData(value: final events)) =>
          AsyncValue.data(
            buildParcelDayIndex(
              parcels: parcels,
              events: events,
              today: DateTime.now(),
            ),
          ),
        (AsyncError(:final error, :final stackTrace), _) => AsyncValue.error(
          error,
          stackTrace,
        ),
        (_, AsyncError(:final error, :final stackTrace)) => AsyncValue.error(
          error,
          stackTrace,
        ),
        _ => const AsyncValue.loading(),
      };
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
        actions: [
          // Explicit month/week toggle instead of table_calendar's
          // cycling format button.
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: SegmentedButton<CalendarFormat>(
              segments: const [
                ButtonSegment(
                  value: CalendarFormat.month,
                  label: Text(StringsKo.calendarFormatMonth),
                ),
                ButtonSegment(
                  value: CalendarFormat.week,
                  label: Text(StringsKo.calendarFormatWeek),
                ),
              ],
              selected: {
                _format == CalendarFormat.week
                    ? CalendarFormat.week
                    : CalendarFormat.month,
              },
              onSelectionChanged: (value) => setState(() {
                _format = value.single;
              }),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const AppBackgroundButton(),
        ],
      ),
      body: byDayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (byDay) {
          final selected =
              byDay[_dateOnly(_selectedDay)] ?? const <DayParcelEntry>[];
          return Column(
            children: [
              TableCalendar<DayParcelEntry>(
                locale: 'ko',
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 90)),
                focusedDay: _focusedDay,
                calendarFormat: _format,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                eventLoader: (day) => byDay[_dateOnly(day)] ?? const [],
                startingDayOfWeek: StartingDayOfWeek.sunday,
                availableCalendarFormats: const {
                  CalendarFormat.month: StringsKo.calendarFormatMonth,
                  CalendarFormat.week: StringsKo.calendarFormatWeek,
                },
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                ),
                calendarBuilders: CalendarBuilders<DayParcelEntry>(
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${events.length}',
                          style: TextStyle(
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
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
                            _DayParcelTile(entry: selected[i]),
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
  final DayParcelEntry entry;

  const _DayParcelTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final parcel = entry.parcel;
    final courierName =
        Couriers.byCode(parcel.courierCode)?.nameKo ?? parcel.courierCode;

    // Day-specific annotation: delivered that day, or that day is the
    // expected arrival date of a parcel still in flight.
    final expected = parcel.expectedArrivalDate;
    final String? badge;
    if (entry.statusOnDay == ParcelStatus.delivered) {
      badge = StringsKo.deliveredBadge;
    } else if (entry.isExpectedPreview ||
        (expected != null && isSameDay(expected, entry.day))) {
      badge = StringsKo.expectedBadge;
    } else {
      badge = null;
    }

    return Card(
      child: ListTile(
        title: Text(
          parcel.productName ?? StringsKo.unknownProduct,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(badge == null ? courierName : '$courierName · $badge'),
        trailing: ParcelStatusBadge(status: entry.statusOnDay),
        onTap: () => context.push('/parcel/${parcel.id}'),
      ),
    );
  }
}

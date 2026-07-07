import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_background_button.dart';
import '../../core/constants/couriers.dart';
import '../../core/courier_registry.dart';
import '../../core/providers.dart';
import '../../core/strings_ko.dart';
import '../parcels/models/parcel.dart';
import '../parcels/widgets/parcel_summary_section.dart';

/// The 4 status buckets this screen filters/groups by. 집하 folds both
/// "상품준비" and "집화" into one bucket, and 배송중 folds "배송출발" in as
/// a later phase of the same in-transit leg; 만료/번호오류 are intentionally
/// not offered here.
enum FilterCategory {
  ordered(StringsKo.filterOrdered, [ParcelStatus.registered]),
  inTransit(StringsKo.filterInTransit, [
    ParcelStatus.inTransit,
    ParcelStatus.outForDelivery,
  ]),
  delivered(StringsKo.filterDelivered, [ParcelStatus.delivered]),
  pickedUp(StringsKo.filterPickedUp, [
    ParcelStatus.preparing,
    ParcelStatus.pickedUp,
  ]);

  final String label;
  final List<ParcelStatus> statuses;
  const FilterCategory(this.label, this.statuses);
}

class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key});

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  Set<String> _courierCodes = {};
  Set<FilterCategory> _categories = {};
  DateTimeRange? _range;

  Set<String> _appliedCourierCodes = {};
  Set<FilterCategory> _appliedCategories = {};
  DateTimeRange? _appliedRange;
  bool _hasApplied = false;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 90)),
      initialDateRange: _range,
      locale: const Locale('ko'),
    );
    if (selected != null) {
      setState(() => _range = selected);
    }
  }

  Future<void> _pickCouriers(List<Courier> couriers) {
    return _showMultiSelectDialog<Courier>(
      title: StringsKo.filterSelectCourier,
      options: couriers,
      labelOf: (c) => c.nameKo,
      isSelected: (c) => _courierCodes.contains(c.code),
      onToggle: (c, selected) => setState(() {
        if (selected) {
          _courierCodes.add(c.code);
        } else {
          _courierCodes.remove(c.code);
        }
      }),
    );
  }

  Future<void> _pickCategories() {
    return _showMultiSelectDialog<FilterCategory>(
      title: StringsKo.filterSelectStatus,
      options: FilterCategory.values,
      labelOf: (c) => c.label,
      isSelected: (c) => _categories.contains(c),
      onToggle: (c, selected) => setState(() {
        if (selected) {
          _categories.add(c);
        } else {
          _categories.remove(c);
        }
      }),
    );
  }

  /// Scrollable checkbox picker with a close (X) button at the top right.
  /// Selections apply immediately via [onToggle] as each checkbox toggles.
  Future<void> _showMultiSelectDialog<T>({
    required String title,
    required List<T> options,
    required String Function(T) labelOf,
    required bool Function(T) isSelected,
    required void Function(T option, bool selected) onToggle,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480, maxWidth: 360),
          child: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final option in options)
                          CheckboxListTile(
                            value: isSelected(option),
                            title: Text(labelOf(option)),
                            onChanged: (checked) {
                              onToggle(option, checked ?? false);
                              setDialogState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _courierCodes = {};
      _categories = {};
      _range = null;
      _appliedCourierCodes = {};
      _appliedCategories = {};
      _appliedRange = null;
      _hasApplied = false;
    });
  }

  void _apply() {
    setState(() {
      _appliedCourierCodes = Set.of(_courierCodes);
      _appliedCategories = Set.of(_categories);
      _appliedRange = _range;
      _hasApplied = true;
    });
  }

  List<Parcel> _filtered(List<Parcel> parcels) {
    final allowedStatuses = _appliedCategories.isEmpty
        ? null
        : _appliedCategories.expand((c) => c.statuses).toSet();
    return parcels.where((p) {
      if (_appliedCourierCodes.isNotEmpty &&
          !_appliedCourierCodes.contains(p.courierCode)) {
        return false;
      }
      if (allowedStatuses != null && !allowedStatuses.contains(p.status)) {
        return false;
      }
      final range = _appliedRange;
      if (range != null) {
        final day = DateUtils.dateOnly(p.registeredAt);
        final start = DateUtils.dateOnly(range.start);
        final end = DateUtils.dateOnly(range.end);
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }
      return true;
    }).toList()..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
  }

  String _summaryText(int count, String allLabel, String singular) {
    if (count == 0) return allLabel;
    return '$singular $count';
  }

  @override
  Widget build(BuildContext context) {
    final rangeText = _range == null
        ? StringsKo.filterDateRange
        : '${_range!.start.month}/${_range!.start.day} - '
              '${_range!.end.month}/${_range!.end.day}';
    final courierText = _summaryText(
      _courierCodes.length,
      StringsKo.allCouriers,
      StringsKo.filterCourier,
    );
    final statusText = _summaryText(
      _categories.length,
      StringsKo.allStatuses,
      StringsKo.filterStatus,
    );
    final parcelsAsync = ref.watch(allParcelsProvider);
    final couriers =
        ref
            .watch(courierListProvider)
            .maybeWhen(data: (v) => v, orElse: () => null) ??
        Couriers.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text(StringsKo.filterTitle),
        actions: const [AppBackgroundButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: () => _pickCouriers(couriers),
            icon: const Icon(Icons.storefront_outlined),
            label: Text(courierText),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickCategories,
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text(statusText),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            label: Text(rangeText),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text(StringsKo.filterApply),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text(StringsKo.filterReset),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          if (!_hasApplied)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  StringsKo.filterNotAppliedHint,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            parcelsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('$e')),
              ),
              data: (parcels) {
                final results = _filtered(parcels);
                final byCategory = {
                  for (final category in FilterCategory.values)
                    category: results
                        .where((p) => category.statuses.contains(p.status))
                        .toList(),
                };

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ParcelSummaryStrip(
                      items: [
                        for (final category in FilterCategory.values)
                          ParcelSummaryItem(
                            label: category.label,
                            value: byCategory[category]!.length,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ParcelSection(
                      title: FilterCategory.ordered.label,
                      icon: Icons.receipt_long_outlined,
                      parcels: byCategory[FilterCategory.ordered]!,
                    ),
                    ParcelSection(
                      title: FilterCategory.inTransit.label,
                      icon: Icons.local_shipping_outlined,
                      parcels: byCategory[FilterCategory.inTransit]!,
                    ),
                    ParcelSection(
                      title: FilterCategory.delivered.label,
                      icon: Icons.check_circle_outline,
                      parcels: byCategory[FilterCategory.delivered]!,
                    ),
                    ParcelSection(
                      title: FilterCategory.pickedUp.label,
                      icon: Icons.move_to_inbox_outlined,
                      parcels: byCategory[FilterCategory.pickedUp]!,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

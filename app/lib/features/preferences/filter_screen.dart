import 'package:flutter/material.dart';

import '../../core/app_background_button.dart';
import '../../core/constants/couriers.dart';
import '../../core/strings_ko.dart';
import '../parcels/models/parcel.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  String _courier = StringsKo.allCouriers;
  String _status = StringsKo.allStatuses;
  DateTimeRange? _range;

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

  void _reset() {
    setState(() {
      _courier = StringsKo.allCouriers;
      _status = StringsKo.allStatuses;
      _range = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final couriers = [
      StringsKo.allCouriers,
      ...Couriers.all.map((c) => c.nameKo),
    ];
    final statuses = [
      StringsKo.allStatuses,
      ...ParcelStatus.values.map((s) => s.labelKo),
    ];
    final rangeText = _range == null
        ? StringsKo.filterDateRange
        : '${_range!.start.month}/${_range!.start.day} - '
              '${_range!.end.month}/${_range!.end.day}';

    return Scaffold(
      appBar: AppBar(
        title: const Text(StringsKo.filterTitle),
        actions: const [AppBackgroundButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _courier,
            decoration: const InputDecoration(
              labelText: StringsKo.filterCourier,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final c in couriers)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (value) => setState(() => _courier = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: StringsKo.filterStatus,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in statuses)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (value) => setState(() => _status = value!),
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
                  onPressed: () {},
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
        ],
      ),
    );
  }
}

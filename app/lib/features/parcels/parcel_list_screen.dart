import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/couriers.dart';
import '../../core/providers.dart';
import '../../core/strings_ko.dart';
import 'models/parcel.dart';

class ParcelListScreen extends ConsumerStatefulWidget {
  const ParcelListScreen({super.key});

  @override
  ConsumerState<ParcelListScreen> createState() => _ParcelListScreenState();
}

class _ParcelListScreenState extends ConsumerState<ParcelListScreen> {
  String? _selectedCourier;

  Future<void> _showCompanyPicker(BuildContext context) async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text(StringsKo.companyPickerTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text(StringsKo.allCouriers),
          ),
          SizedBox(
            width: 320,
            height: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final courier in Couriers.all)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, courier.code),
                    child: Text(courier.nameKo),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    setState(() => _selectedCourier = selected);
  }

  @override
  Widget build(BuildContext context) {
    final title = _selectedCourier == null
        ? StringsKo.parcelListTitle
        : Couriers.byCode(_selectedCourier!)?.nameKo ??
              StringsKo.parcelListTitle;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              tooltip: StringsKo.companyPickerTitle,
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () => _showCompanyPicker(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: StringsKo.tabActive),
              Tab(text: StringsKo.tabDone),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ParcelTab(
              provider: activeParcelsProvider,
              emptyText: StringsKo.emptyActive,
              courierFilter: _selectedCourier,
            ),
            _ParcelTab(
              provider: doneParcelsProvider,
              emptyText: StringsKo.emptyDone,
              courierFilter: _selectedCourier,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: StringsKo.manualInsertTitle,
          onPressed: () => context.push('/parcels/new'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _ParcelTab extends ConsumerWidget {
  final StreamProvider<List<Parcel>> provider;
  final String emptyText;
  final String? courierFilter;

  const _ParcelTab({
    required this.provider,
    required this.emptyText,
    required this.courierFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcels = ref.watch(provider);
    return parcels.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) {
        final visible = courierFilter == null
            ? list
            : list.where((p) => p.courierCode == courierFilter).toList();
        if (visible.isEmpty) {
          return Center(
            child: Text(
              emptyText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: visible.length,
          itemBuilder: (context, i) => _ParcelCard(parcel: visible[i]),
        );
      },
    );
  }
}

class _ParcelCard extends StatelessWidget {
  final Parcel parcel;

  const _ParcelCard({required this.parcel});

  String? _arrivalText() {
    final date = parcel.expectedArrivalDate;
    if (date == null || parcel.status.isTerminal) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    final target = DateUtils.dateOnly(date);
    final diff = target.difference(today).inDays;
    if (diff == 0) return StringsKo.arrivalToday;
    if (diff == 1) return StringsKo.arrivalTomorrow;
    final formatted = DateFormat('M월 d일 (E)', 'ko').format(target);
    return diff > 1 ? '$formatted 도착 예정 (D-$diff)' : '$formatted 도착 예정이었음';
  }

  @override
  Widget build(BuildContext context) {
    final courierName =
        Couriers.byCode(parcel.courierCode)?.nameKo ?? parcel.courierCode;
    final arrival = _arrivalText();

    return Card(
      child: ListTile(
        onTap: () => context.push('/parcel/${parcel.id}'),
        title: Text(
          parcel.productName ?? StringsKo.unknownProduct,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              [
                courierName,
                if (parcel.mallName != null) parcel.mallName!,
                if (!parcel.trackingNumber.startsWith('cp:'))
                  parcel.trackingNumber,
              ].join(' · '),
            ),
            if (arrival != null) ...[
              const SizedBox(height: 2),
              Text(
                arrival,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        trailing: Chip(
          label: Text(
            parcel.status.labelKo,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: parcel.status.color,
          visualDensity: VisualDensity.compact,
          side: BorderSide.none,
        ),
        isThreeLine: arrival != null,
      ),
    );
  }
}

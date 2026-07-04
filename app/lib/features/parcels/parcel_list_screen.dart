import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/couriers.dart';
import '../../core/providers.dart';
import '../../core/strings_ko.dart';
import 'models/parcel.dart';

class ParcelListScreen extends ConsumerWidget {
  const ParcelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(StringsKo.parcelListTitle),
          actions: [
            if (kDebugMode)
              IconButton(
                tooltip: StringsKo.replayTitle,
                icon: const Icon(Icons.science_outlined),
                onPressed: () => context.push('/debug/replay'),
              ),
            IconButton(
              tooltip: StringsKo.logout,
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
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
            ),
            _ParcelTab(
              provider: doneParcelsProvider,
              emptyText: StringsKo.emptyDone,
            ),
          ],
        ),
        // Manual insert is a development aid only; capture is automatic
        // in the real flow, so the FAB exists only in debug builds.
        floatingActionButton: kDebugMode
            ? FloatingActionButton(
                onPressed: () => context.push('/debug/insert'),
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}

class _ParcelTab extends ConsumerWidget {
  final StreamProvider<List<Parcel>> provider;
  final String emptyText;

  const _ParcelTab({required this.provider, required this.emptyText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcels = ref.watch(provider);
    return parcels.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              emptyText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, i) => _ParcelCard(parcel: list[i]),
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

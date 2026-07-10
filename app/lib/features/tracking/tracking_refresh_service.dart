import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/couriers.dart';
import '../../core/providers.dart';
import '../parcels/models/parcel.dart';
import '../parcels/parcel_repository.dart';
import 'sweettracker_client.dart';
import 'tracking_api_settings.dart';

final trackingRefreshServiceProvider = Provider<TrackingRefreshService>((ref) {
  final client = SweettrackerClient();
  ref.onDispose(client.close);
  return TrackingRefreshService(
    repository: ref.watch(parcelRepositoryProvider),
    client: client,
    keyStore: ref.watch(sweettrackerKeyStoreProvider),
    quota: ref.watch(trackingQuotaStoreProvider),
  );
});

enum RefreshOutcome {
  /// Query succeeded and the parcel advanced to a newer status.
  updated,

  /// Query succeeded; nothing newer than what notifications already gave us.
  unchanged,

  /// Courier has no Sweet Tracker code (Coupang direct, user-added).
  unsupported,

  /// Parcel is already terminal; no call spent.
  alreadyDone,

  /// No API key registered — the optional feature is off.
  missingKey,

  /// Today's call budget is used up.
  quotaExceeded,

  /// Network/server/parse failure; message carries the reason.
  failed;
}

class RefreshResult {
  final RefreshOutcome outcome;
  final String? message;

  const RefreshResult(this.outcome, {this.message});
}

class RefreshSummary {
  final int updated;
  final int unchanged;
  final int failed;
  final int skipped;
  final bool quotaExceeded;
  final bool missingKey;

  const RefreshSummary({
    this.updated = 0,
    this.unchanged = 0,
    this.failed = 0,
    this.skipped = 0,
    this.quotaExceeded = false,
    this.missingKey = false,
  });

  int get attempted => updated + unchanged + failed;
}

/// Optional on-demand tracking sync via the Sweet Tracker API.
/// Notifications stay the primary source; this only fills gaps when the
/// user taps refresh, and every call is metered by [DailyQuotaStore].
class TrackingRefreshService {
  final ParcelRepository repository;
  final SweettrackerClient client;
  final SweettrackerKeyStore keyStore;
  final DailyQuotaStore quota;

  TrackingRefreshService({
    required this.repository,
    required this.client,
    required this.keyStore,
    required this.quota,
  });

  /// Refreshes one parcel from the tracking API and merges the result
  /// through the normal repository path (monotonic status, dedupe).
  Future<RefreshResult> refreshParcel(Parcel parcel) async {
    if (parcel.status.isTerminal) {
      return const RefreshResult(RefreshOutcome.alreadyDone);
    }
    final courier = Couriers.byCode(parcel.courierCode);
    final apiCode = courier?.sweettrackerCode;
    if (apiCode == null) {
      return const RefreshResult(RefreshOutcome.unsupported);
    }
    final apiKey = await keyStore.read();
    if (apiKey == null) {
      return const RefreshResult(RefreshOutcome.missingKey);
    }
    if (!await quota.tryConsume()) {
      return const RefreshResult(RefreshOutcome.quotaExceeded);
    }

    final TrackingQueryResult result;
    try {
      result = await client.fetchTrackingInfo(
        apiKey: apiKey,
        courierApiCode: apiCode,
        invoice: parcel.trackingNumber,
      );
    } on SweettrackerException catch (e) {
      return RefreshResult(RefreshOutcome.failed, message: e.message);
    }

    if (!parcel.status.canTransitionTo(result.status)) {
      return const RefreshResult(RefreshOutcome.unchanged);
    }

    final last = result.lastDetail;
    final eventTime = last?.time ?? DateTime.now();
    final note = [
      '스마트택배 조회',
      if (last?.where != null && last!.where!.isNotEmpty) last.where,
      if (last?.kind != null && last!.kind!.isNotEmpty) last.kind,
    ].join(' · ');

    await repository.upsert(
      Parcel(
        id: parcel.id,
        courierCode: parcel.courierCode,
        trackingNumber: parcel.trackingNumber,
        status: result.status,
        productName: parcel.productName ?? result.itemName,
        // Upsert uses the sighting's registeredAt as the timeline event
        // time, so pass the courier-side event time here.
        registeredAt: eventTime,
        deliveredAt: result.status == ParcelStatus.delivered
            ? eventTime
            : null,
      ),
      eventNote: note,
    );
    return const RefreshResult(RefreshOutcome.updated);
  }

  /// Refreshes every non-terminal parcel with a supported courier.
  /// Sequential on purpose: cheap on quota accounting and gentle on the
  /// free-tier API.
  Future<RefreshSummary> refreshAllActive() async {
    if (await keyStore.read() == null) {
      return const RefreshSummary(missingKey: true);
    }

    final parcels = await repository.watchActive().first;
    var updated = 0, unchanged = 0, failed = 0, skipped = 0;
    var quotaExceeded = false;

    for (final parcel in parcels) {
      final result = await refreshParcel(parcel);
      switch (result.outcome) {
        case RefreshOutcome.updated:
          updated++;
        case RefreshOutcome.unchanged:
          unchanged++;
        case RefreshOutcome.failed:
          failed++;
        case RefreshOutcome.unsupported || RefreshOutcome.alreadyDone:
          skipped++;
        case RefreshOutcome.quotaExceeded:
          quotaExceeded = true;
        case RefreshOutcome.missingKey:
          return const RefreshSummary(missingKey: true);
      }
      if (quotaExceeded) break;
    }
    return RefreshSummary(
      updated: updated,
      unchanged: unchanged,
      failed: failed,
      skipped: skipped,
      quotaExceeded: quotaExceeded,
    );
  }
}

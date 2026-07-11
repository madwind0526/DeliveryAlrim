import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/adaptive_text.dart';
import '../../../core/constants/couriers.dart';
import '../../../core/strings_ko.dart';
import '../models/parcel.dart';
import 'parcel_status_badge.dart';

/// Compact parcel row shared by the today dashboard and filter results:
/// product name, courier/mall/tracking, and a trailing status badge.
class ParcelTile extends StatelessWidget {
  final Parcel parcel;

  const ParcelTile({super.key, required this.parcel});

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
            if (!parcel.hasSyntheticTrackingNumber) parcel.trackingNumber,
          ].join(' · '),
        ),
        trailing: ParcelStatusBadge(status: parcel.status),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/adaptive_text.dart';
import '../../../core/strings_ko.dart';
import '../models/parcel.dart';
import 'parcel_tile.dart';

/// One count tile in a [ParcelSummaryStrip].
class ParcelSummaryItem {
  final String label;
  final int value;

  const ParcelSummaryItem({required this.label, required this.value});
}

/// 4-up (2-up on narrow screens) grid of count cards, shared by the today
/// dashboard and the filter results screen.
class ParcelSummaryStrip extends StatelessWidget {
  final List<ParcelSummaryItem> items;

  const ParcelSummaryStrip({super.key, required this.items});

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
      children: [for (final item in items) _SummaryCard(item: item)],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ParcelSummaryItem item;

  const _SummaryCard({required this.item});

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
                '${item.value}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              AdaptiveText(
                item.label,
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

/// A titled group of [ParcelTile]s with an empty-state fallback, shared by
/// the today dashboard and the filter results screen.
class ParcelSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Parcel> parcels;

  const ParcelSection({
    super.key,
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
            for (final parcel in parcels) ParcelTile(parcel: parcel),
        ],
      ),
    );
  }
}

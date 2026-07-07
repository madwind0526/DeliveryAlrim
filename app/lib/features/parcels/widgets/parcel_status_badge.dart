import 'package:flutter/material.dart';

import '../models/parcel.dart';

class ParcelStatusBadge extends StatelessWidget {
  final ParcelStatus status;

  const ParcelStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _badgeColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                status.labelKo,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _textColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _badgeColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return status.isTerminal
        ? colors.surfaceContainerHighest
        : colors.surfaceContainerHigh;
  }

  Color _borderColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return status.isTerminal
        ? colors.outline.withValues(alpha: 0.55)
        : colors.outline.withValues(alpha: 0.35);
  }

  Color _textColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (status) {
      ParcelStatus.outForDelivery =>
        isDark ? const Color(0xFFFFE08A) : const Color(0xFF7A5200),
      ParcelStatus.inTransit =>
        isDark ? const Color(0xFFFFA3A3) : const Color(0xFF9A3030),
      ParcelStatus.delivered =>
        isDark ? const Color(0xFF8FF0A4) : const Color(0xFF1F713A),
      _ => isDark ? Colors.white : const Color(0xFF252525),
    };
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class ResponsiveTextPolicy {
  static TextScaler scalerFor(MediaQueryData media) {
    final width = media.size.shortestSide;
    final userScale = media.textScaler.scale(1);
    final maxScale = _maxScaleForWidth(width);
    return TextScaler.linear(math.min(userScale, maxScale));
  }

  static double _maxScaleForWidth(double width) {
    if (width < 320) return 0.95;
    if (width < 360) return 1.0;
    if (width < 400) return 1.08;
    if (width < 480) return 1.16;
    if (width < 600) return 1.25;
    if (width < 840) return 1.35;
    return 1.5;
  }
}

import 'package:flutter/material.dart';

class AdaptiveText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign textAlign;
  final Alignment alignment;

  const AdaptiveText(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        data,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

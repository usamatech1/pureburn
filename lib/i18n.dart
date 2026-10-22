// Text wrapper kept for the whole app. The app is English only.
import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' show TextStyle, TextAlign, TextOverflow, TextSpan, StatelessWidget, BuildContext, Widget, Key;

/// The app is English only, so this returns the text unchanged.
String tr(String s) => s;

/// Drop-in replacement for Flutter's Text that translates its string.
class Text extends StatelessWidget {
  final String? data;
  final TextSpan? span;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  const Text(String this.data, {super.key, this.style, this.textAlign, this.maxLines, this.overflow, this.softWrap}) : span = null;
  const Text.rich(TextSpan this.span, {super.key, this.style, this.textAlign, this.maxLines, this.overflow, this.softWrap}) : data = null;

  TextSpan _tr(TextSpan s) => TextSpan(
        text: s.text == null ? null : tr(s.text!),
        style: s.style,
        children: s.children?.map((c) => c is TextSpan ? _tr(c) : c).toList(),
      );

  @override
  Widget build(BuildContext context) {
    if (span != null) {
      return m.Text.rich(_tr(span!), style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow, softWrap: softWrap);
    }
    return m.Text(tr(data!), style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow, softWrap: softWrap);
  }
}

// Language support: English, Urdu (right to left) and Roman Urdu.
// Every Text in the app goes through tr(), so new screens only need their words added to the lists.
import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' show TextStyle, TextAlign, TextOverflow, TextSpan, StatelessWidget, BuildContext, Widget, Key;
import 'main.dart' show app;
import 'i18n_words.dart';
import 'i18n_words2.dart';

Map<String, List<String>>? _all;
List<MapEntry<RegExp, List<String>>>? _frags;
final Map<String, String> _cache = {};
String _cacheLang = '';

Map<String, List<String>> _dict() => _all ??= {...wordsA, ...wordsB};

List<MapEntry<RegExp, List<String>>> _fragList() {
  if (_frags != null) return _frags!;
  final keys = _dict().keys.where((k) => k.length >= 2 && !k.contains('#') && RegExp(r'[A-Za-z]').hasMatch(k)).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  _frags = [
    for (final k in keys) MapEntry(RegExp('(?<![A-Za-z])${RegExp.escape(k)}(?![A-Za-z])'), _dict()[k]!),
  ];
  return _frags!;
}

String tr(String s) {
  final l = app.lang;
  if (l == 'en' || s.isEmpty) return s;
  if (_cacheLang != l) {
    _cache.clear();
    _cacheLang = l;
  }
  final hit = _cache[s];
  if (hit != null) return hit;
  final out = _translate(s, l == 'ur' ? 0 : 1);
  if (_cache.length > 3000) _cache.clear();
  _cache[s] = out;
  return out;
}

String _translate(String s, int i) {
  final d = _dict();
  final e = d[s];
  if (e != null) return e[i];
  // Strings with numbers: match a template such as "# of # tasks done".
  final nums = <String>[];
  final key = s.replaceAllMapped(RegExp(r'\d+(?:[.,]\d+)*'), (mm) {
    nums.add(mm[0]!);
    return '#';
  });
  if (nums.isNotEmpty) {
    final t = d[key];
    if (t != null) {
      var o = t[i];
      for (var k = 0; k < nums.length; k++) {
        o = o.replaceAll('{${k + 1}}', nums[k]);
      }
      return o;
    }
  }
  // Otherwise swap the known words and phrases inside the text.
  var out = s;
  final holders = <String>[];
  for (final f in _fragList()) {
    if (!f.key.hasMatch(out)) continue;
    out = out.replaceAllMapped(f.key, (mm) {
      holders.add(f.value[i]);
      return '${String.fromCharCode(0xE100 + holders.length - 1)}';
    });
  }
  for (var k = 0; k < holders.length; k++) {
    out = out.replaceAll('${String.fromCharCode(0xE100 + k)}', holders[k]);
  }
  return out;
}

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

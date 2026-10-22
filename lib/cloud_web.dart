// Web helpers for Google sign-in by redirect.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void webGo(String url) => html.window.location.assign(url);

void webCleanUrl() {
  try {
    final l = html.window.location;
    html.window.history.replaceState(null, '', '${l.origin}${l.pathname}');
  } catch (_) {}
}

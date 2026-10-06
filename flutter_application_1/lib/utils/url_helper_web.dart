// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Browser-native URL launcher that opens the URL in a new tab.
void openUrlInBrowser(String url) {
  var target = url.trim();
  if (target.isEmpty) return;
  if (!target.startsWith('http://') && !target.startsWith('https://')) {
    target = 'https://$target';
  }
  html.window.open(target, '_blank');
}

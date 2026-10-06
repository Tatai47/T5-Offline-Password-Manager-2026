import 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart' as impl;

/// Opens the specified URL in a new browser tab or window.
/// Automatically handles prepending 'https://' if missing.
void openUrlInBrowser(String url) {
  impl.openUrlInBrowser(url);
}

/// Extracts domain or host from a URL (e.g. "https://www.amazon.in/" -> "amazon.in")
String? extractDomain(String? url) {
  if (url == null) return null;
  var trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    trimmed = 'https://$trimmed';
  }
  try {
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.host.isNotEmpty) {
      // Strip leading 'www.' if present for clean canonical domain resolution
      return uri.host.replaceFirst(RegExp(r'^www\.'), '');
    }
  } catch (_) {}
  return null;
}

/// Generates a CORS-compliant high-resolution favicon service URL for Flutter Web.
/// Primary provider: icon.horse (Sends Access-Control-Allow-Origin: * to prevent CORS blocking)
String? getFaviconUrl(String? websiteUrl, {int size = 128}) {
  final domain = extractDomain(websiteUrl);
  if (domain == null || domain.isEmpty) return null;
  return 'https://icon.horse/icon/$domain';
}

/// Secondary CORS-friendly backup favicon service
String? getBackupFaviconUrl(String? websiteUrl, {int size = 128}) {
  final domain = extractDomain(websiteUrl);
  if (domain == null || domain.isEmpty) return null;
  return 'https://favicone.com/$domain?s=$size';
}



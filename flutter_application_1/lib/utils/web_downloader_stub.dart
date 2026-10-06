/// Fallback stub for non-web platforms (Android, iOS, Windows, macOS, Linux, and VM tests).
Future<bool> downloadWebFile({
  required String fileName,
  required String content,
}) async {
  return false;
}

/// Whether a source url is a torrent (magnet link or .torrent file) rather
/// than a directly-playable http(s) url.
bool isTorrentUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('magnet:') || u.endsWith('.torrent');
}


/// Builds a Stremio-compatible magnet URI. The selected file index is kept
/// separately on VideoSource and passed to the native torrent engine.
String? buildTorrentMagnet({
  required String infoHash,
  List<String> trackers = const [],
}) {
  final hash = infoHash.trim();
  if (hash.isEmpty) return null;
  final parts = <String>['xt=urn:btih:${Uri.encodeComponent(hash)}'];
  for (final tracker in trackers) {
    final value = tracker.trim();
    if (value.isNotEmpty) {
      parts.add('tr=${Uri.encodeComponent(value)}');
    }
  }
  return 'magnet:?\u0024{parts.join('&')}';
}

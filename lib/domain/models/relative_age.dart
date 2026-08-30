/// Formats how long ago a site was last opened, in the compact form the
/// dashboard uses: `now`, `14m`, `2h`, `3d`, `2w`.
///
/// Returns an empty string when the site has never been opened. A [then] in
/// the future (a clock change) reads as `now` rather than a negative age.
String relativeAge(DateTime now, DateTime? then) {
  if (then == null) return '';

  final elapsed = now.difference(then);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d';
  return '${elapsed.inDays ~/ 7}w';
}

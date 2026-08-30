/// What the user can do with a file a site tried to save. Spec `7c`.
enum DownloadDecision { keepInContainer, saveToDevice, discard }

class HeldDownload {
  const HeldDownload({
    required this.fileName,
    required this.sizeBytes,
    required this.sourceHost,
    required this.kindLabel,
  });

  final String fileName;
  final int sizeBytes;
  final String sourceHost;

  /// The short badge on the file icon — "PDF" in the spec's example.
  final String kindLabel;
}

/// The compact size string the sheet's meta line uses: "1.4 MB", "2.0 KB",
/// "512 B".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

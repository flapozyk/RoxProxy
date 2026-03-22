class DataFormatting {
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String formatDuration(Duration? duration) {
    if (duration == null) return '—';
    final ms = duration.inMilliseconds;
    if (ms < 1000) return '${ms} ms';
    return '${(ms / 1000).toStringAsFixed(2)} s';
  }
}

import 'package:flutter/foundation.dart' show protected;

/// Timestamps over a key/value meta table. Both databases keep one;
/// stamps are written as UTC ISO-8601 and read back in local time.
mixin MetaTimestamps {
  @protected
  Future<String?> readMeta(String key);

  @protected
  Future<void> writeMeta(String key, String value);

  @protected
  Future<DateTime?> readTimestamp(String key) async {
    final raw = await readMeta(key);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  @protected
  Future<void> writeTimestamp(String key, DateTime ts) =>
      writeMeta(key, ts.toUtc().toIso8601String());
}

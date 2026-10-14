import 'dart:convert';

/// Decodes a `text/event-stream` body into the payload of each event's
/// `data:` lines (joined with `\n`). Comment lines (`: keep-alive`) and
/// the other fields are dropped; chunk boundaries may fall anywhere,
/// including inside a UTF-8 sequence.
Stream<String> sseData(Stream<List<int>> bytes) async* {
  final pending = <String>[];
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (pending.isNotEmpty) {
        yield pending.join('\n');
        pending.clear();
      }
      continue;
    }
    if (line.startsWith(':')) continue;
    if (line.startsWith('data:')) {
      var value = line.substring(5);
      if (value.startsWith(' ')) value = value.substring(1);
      pending.add(value);
    }
  }
  if (pending.isNotEmpty) yield pending.join('\n');
}
